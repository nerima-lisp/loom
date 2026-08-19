;;;; t/unit/editor-state-test.lisp
;;;;
;;;; Editor-state operation tests.  These isolate save hooks, recent-file
;;;; tracking, and transient yank bookkeeping from workspace-manager tests so
;;;; the top-level state helpers stay observable as one slice.
(in-package #:loom/test)

(describe "editor-state save hooks"
  (it "rejects registering save hooks without an active state"
    (let ((hook (lambda (buffer) buffer)))
      (signals error (add-before-save-hook hook nil))
      (signals error (add-after-save-hook hook nil))))

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
