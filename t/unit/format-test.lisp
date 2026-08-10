(in-package #:loom/test)

(describe
  "format-buffer-with-command"
  (it "replaces the buffer in one undo group and preserves point and mark"
    (let ((buffer (make-buffer :name "format.lisp"
                               :initial-content (format nil "abc~%def"))))
      (buffer-set-point buffer 0 2)
      (buffer-set-mark buffer 1 1)
      (let ((result (format-buffer-with-command
                     "tr 'a-z' 'A-Z'"
                     buffer)))
        (expect (shell-command-result-success-p result) :to-be-truthy)
        (expect (buffer-text buffer) :to-equal (format nil "ABC~%DEF"))
        (expect (buffer-point-line buffer) :to-equal 0)
        (expect (buffer-point-column buffer) :to-equal 2)
        (multiple-value-bind (line column) (buffer-mark buffer)
          (expect line :to-equal 1)
          (expect column :to-equal 1))
        (expect (buffer-modified-p buffer) :to-be-truthy)
        (buffer-undo buffer)
        (expect (buffer-text buffer) :to-equal (format nil "abc~%def"))))
  (it "does not mutate the buffer when the formatter fails"
    (let ((buffer (make-buffer :initial-content "keep")))
      (buffer-set-point buffer 0 2)
      (let ((result (format-buffer-with-command
                     "printf 'diagnostic' >&2; exit 9"
                     buffer)))
        (expect (shell-command-result-success-p result) :to-be-falsy)
        (expect (shell-command-result-exit-code result) :to-equal 9)
        (expect (buffer-text buffer) :to-equal "keep")
        (expect (buffer-point-column buffer) :to-equal 2)
        (expect (buffer-modified-p buffer) :to-be nil))))
  (it "reports the public buffer predicate for non-buffer inputs"
    (let ((condition nil))
      (handler-case
          (format-buffer-with-command "printf bad" :not-a-buffer)
        (type-error (caught)
          (setf condition caught)))
      (expect condition :to-be-truthy)
      (expect (type-error-expected-type condition)
              :to-equal '(satisfies loom:buffer-p)))))
  (it "rejects read-only and narrowed buffers before invoking the command"
    (let ((read-only (make-buffer :initial-content "read-only"))
          (narrowed (make-buffer :initial-content "one\ntwo")))
      (buffer-set-read-only read-only t)
      (signals buffer-read-only-error
        (format-buffer-with-command "printf bad" read-only))
      (buffer-narrow-to-region narrowed 0 0 0 3)
      (signals error
        (format-buffer-with-command "printf bad" narrowed)))))

(describe
  "format-current-buffer"
  (it "prompts for a formatter and reports successful completion"
    (let* ((buffer (make-buffer :initial-content "abc"))
           (tree (make-window-tree buffer 80 24))
           (state (make-editor-state
                   :window-tree tree
                   :workspaces (make-workspace-manager tree :name "main")
                   :minibuffer (make-minibuffer)
                   :keymap (make-keymap)
                   :file-tree nil
                   :renderer nil
                   :buffers (list buffer)
                   :kill-ring nil)))
      (let ((*editor-state* state)
            (minibuffer (editor-state-minibuffer state)))
        (format-current-buffer)
        (expect (minibuffer-prompt-string minibuffer)
                :to-equal "Format command: ")
        (funcall (loom::%minibuffer-on-confirm minibuffer)
                 "tr 'a-z' 'A-Z'")
        (expect (buffer-text buffer) :to-equal "ABC")
        (expect (minibuffer-message-string minibuffer)
                :to-equal "Buffer formatted successfully")))))

(describe
  "format-on-save"
  (it "formats the buffer before the file is written"
    (host-kit:with-temporary-directory (directory)
      (let* ((path (merge-pathnames "notes.txt" directory))
             (buffer (make-buffer :name "notes.txt"
                                  :path path
                                  :initial-content "draft"))
             (tree (make-window-tree buffer 80 24))
             (state (make-editor-state
                     :window-tree tree
                     :workspaces (make-workspace-manager tree :name "main")
                     :minibuffer (make-minibuffer)
                     :keymap (make-keymap)
                     :file-tree nil
                     :renderer nil
                     :buffers (list buffer)
                     :kill-ring nil)))
        (buffer-mark-modified buffer)
        (let ((*editor-state* state))
          (set-format-command "tr 'a-z' 'A-Z'" state)
          (add-before-save-hook #'format-before-save state)
          (expect (format-on-save-mode t state) :to-be-truthy)
          (expect (buffer-save buffer) :to-be buffer))
        (expect (buffer-text buffer) :to-equal "DRAFT")
        (expect (host-kit:read-file-string path) :to-equal "DRAFT")
        (expect (buffer-modified-p buffer) :to-be-falsy)))))
