;;;; t/unit/editor-state-test.lisp
;;;;
;;;; Editor-state operation tests.  These isolate save hooks, recent-file
;;;; tracking, and transient yank bookkeeping from workspace-manager tests so
;;;; the top-level state helpers stay observable as one slice.
(in-package #:loom/test)

(defmacro %editor-state-accessor-contract-test ()
  `(it "exposes every public editor-state slot accessor"
      (let ((state (make-editor-state)))
        (dolist (slot '(window-tree workspaces minibuffer keymap file-tree
                        concurrent-runtime renderer buffers recent-files
                        bookmarks kill-ring last-yank-ranges lsp-session
                        registers keyboard-macro isearch auto-save-mode-p
                        auto-save-buffers auto-save-last-run-at format-on-save-p
                        format-command before-save-hooks after-save-hooks
                        terminal-sessions prefix-argument))
          (let ((accessor (intern (format nil "EDITOR-STATE-~A" slot)
                                  (find-package :loom))))
            (expect (fboundp accessor) :to-be-truthy)
            (expect (handler-case
                        (progn (funcall accessor state) t)
                      (error () nil))
                    :to-be-truthy))))))

(%editor-state-accessor-contract-test)

(describe "editor-state save hooks"
  (it "rejects registering save hooks without an active state"
    (let ((hook (lambda (buffer) buffer)))
      (signals error (add-before-save-hook hook nil))
      (signals error (add-after-save-hook hook nil))))

  (it "rejects non-function save hooks and keeps empty dispatch harmless"
    (let ((state (make-editor-state)))
      (signals error (add-before-save-hook :not-a-function state))
      (signals error (add-after-save-hook :not-a-function state))
      (let ((buffer (make-buffer :name "notes.txt")))
        (expect (run-before-save-hooks buffer nil) :to-be buffer)
        (expect (run-after-save-hooks buffer nil) :to-be buffer))))

  (it "runs before-save hooks in registration order without duplicates"
    (let* ((buffer (make-buffer :name "notes.txt" :initial-content "draft"))
           (state (make-editor-state :window-tree (make-window-tree buffer 80 24)))
           (events nil)
           (first-hook (lambda (saved-buffer)
                         (push (list :first saved-buffer) events)))
           (second-hook (lambda (saved-buffer)
                          (push (list :second saved-buffer) events))))
      (add-before-save-hook first-hook state)
      (add-before-save-hook second-hook state)
      (add-before-save-hook first-hook state)
      (expect (run-before-save-hooks buffer state) :to-be buffer)
      (expect (reverse events)
              :to-equal
              (list (list :first buffer)
                    (list :second buffer)))))

  (it "copies the before-save hook list before dispatch"
    (let* ((buffer (make-buffer :name "notes.txt" :initial-content "draft"))
           (state (make-editor-state :window-tree (make-window-tree buffer 80 24)))
           (events nil)
           (second-hook nil)
           (first-hook (lambda (saved-buffer)
                         (declare (ignore saved-buffer))
                         (remove-before-save-hook second-hook state)
                         (push :first events))))
      (setf second-hook
            (lambda (saved-buffer)
              (declare (ignore saved-buffer))
              (push :second events)))
      (add-before-save-hook first-hook state)
      (add-before-save-hook second-hook state)
      (run-before-save-hooks buffer state)
      (expect (reverse events) :to-equal '(:first :second))
      (setf events nil)
      (run-before-save-hooks buffer state)
      (expect (reverse events) :to-equal '(:first))))

  (it "runs after-save hooks in registration order and honors later removals"
    (let* ((buffer (make-buffer :name "notes.txt" :initial-content "draft"))
           (state (make-editor-state :window-tree (make-window-tree buffer 80 24)))
           (events nil)
           (second-hook nil)
           (first-hook (lambda (saved-buffer)
                         (push (list :first saved-buffer) events)
                         (remove-after-save-hook second-hook state))))
      (setf second-hook
            (lambda (saved-buffer)
              (push (list :second saved-buffer) events)))
      (add-after-save-hook first-hook state)
      (add-after-save-hook second-hook state)
      (add-after-save-hook first-hook state)
      (expect (run-after-save-hooks buffer state) :to-be buffer)
      (expect (reverse events)
              :to-equal
              (list (list :first buffer)
                    (list :second buffer)))
      (setf events nil)
      (run-after-save-hooks buffer state)
      (expect (reverse events)
              :to-equal
              (list (list :first buffer)))))

  (it "deduplicates registration and returns the hook from removal"
    (let* ((state (make-editor-state))
           (hook (lambda (buffer) buffer)))
      (add-before-save-hook hook state)
      (add-before-save-hook hook state)
      (expect (editor-state-before-save-hooks state) :to-equal (list hook))
      (expect (remove-before-save-hook hook state) :to-be hook)
      (expect (editor-state-before-save-hooks state) :to-be nil)
      (expect (remove-after-save-hook hook state) :to-be hook)))

  (it "tolerates an absent state when running after-save hooks"
    (let* ((buffer (make-buffer :name "notes.txt" :initial-content "draft"))
           (state (make-editor-state :window-tree (make-window-tree buffer 80 24)))
           (calls 0))
      (add-after-save-hook (lambda (saved-buffer)
                             (declare (ignore saved-buffer))
                             (incf calls))
                           state)
      (expect (run-after-save-hooks buffer nil) :to-be buffer)
      (expect calls :to-equal 0))))
