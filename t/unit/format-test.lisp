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
  (it "leaves an already formatted buffer and an unset mark unchanged"
    (let ((buffer (make-buffer :initial-content "already")))
      (buffer-set-point buffer 0 3)
      (with-replaced-function
          (loom/feature/shell:run-shell-command
           (lambda (command &key directory input)
             (expect command :to-equal "cat")
             (expect directory :to-equal (uiop:getcwd))
             (expect input :to-equal "already")
             (make-shell-command-result :command command
                                        :directory directory
                                        :output input
                                        :error-output ""
                                        :exit-code 0)))
        (let ((result (format-buffer-with-command "cat" buffer)))
          (expect (shell-command-result-success-p result) :to-be-truthy)
          (expect (buffer-text buffer) :to-equal "already")
          (expect (buffer-point-column buffer) :to-equal 3)
          (multiple-value-bind (line column) (buffer-mark buffer)
            (expect line :to-be nil)
            (expect column :to-be nil))))))
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
  (it "reports a formatter exit status"
    (%with-minibuffer-state (minibuffer "abc")
      (format-current-buffer)
      (funcall (loom::%minibuffer-on-confirm minibuffer)
               "printf bad >&2; exit 4")
      (expect (minibuffer-message-string minibuffer)
              :to-equal "Formatter exited with code 4")))
  (it "does nothing when the formatter prompt is cancelled"
    (%with-minibuffer-state (minibuffer "abc")
      (format-current-buffer)
      (expect (loom::%minibuffer-on-cancel minibuffer) :to-be-truthy)
      (funcall (loom::%minibuffer-on-cancel minibuffer))
      (expect (buffer-text (%selected-test-buffer)) :to-equal "abc")))
  (it "reports formatter conditions from the interactive command"
    (%with-minibuffer-state (minibuffer "abc")
      (with-replaced-function
          (loom/feature/format:format-buffer-with-command
           (lambda (&rest arguments)
             (declare (ignore arguments))
             (error "formatter unavailable")))
        (format-current-buffer)
        (funcall (loom::%minibuffer-on-confirm minibuffer) "fmt")
        (expect (minibuffer-message-string minibuffer)
                :to-contain "Format command error: formatter unavailable"))))

(describe
  "format infrastructure boundaries"
  (it "runs a formatter in the directory of a file-backed buffer"
    (host-kit:with-temporary-directory (directory)
      (let ((buffer (make-buffer :path (merge-pathnames "notes.txt" directory)
                                 :initial-content "draft"))
            captured-directory)
        (with-replaced-function
            (loom/feature/shell:run-shell-command
             (lambda (command &key directory input)
               (declare (ignore command input))
               (setf captured-directory directory)
               (make-shell-command-result
                :command "cat" :directory directory :output "draft"
                :error-output "" :exit-code 0)))
          (format-buffer-with-command "cat" buffer)
          (expect captured-directory
                  :to-equal (namestring directory)))))))

(describe
  "format-before-save guards"
  (it "leaves a buffer untouched when format-on-save is inactive"
    (%with-minibuffer-state (minibuffer "text")
      (let ((buffer (%selected-test-buffer)))
        (expect (format-before-save buffer *editor-state*) :to-be buffer)
        (expect (minibuffer-message-string minibuffer) :to-be nil))))
  (it "reports formatter conditions without aborting a save"
    (%with-minibuffer-state (minibuffer "text")
      (set-format-command "fmt" *editor-state*)
      (format-on-save-mode t *editor-state*)
      (with-replaced-function
          (loom/feature/format:format-buffer-with-command
           (lambda (&rest arguments)
             (declare (ignore arguments))
             (error "formatter unavailable")))
        (expect (format-before-save (%selected-test-buffer) *editor-state*)
                :to-be (%selected-test-buffer))
        (expect (minibuffer-message-string minibuffer)
                :to-contain "Format-on-save error: formatter unavailable")))))

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

(describe
  "format configuration"
  (it "trims a configured formatter and rejects an empty command"
    (let ((state (%fresh-editor-state "text")))
      (expect (set-format-command "  printf ok  " state)
              :to-equal "printf ok")
      (expect (editor-state-format-command state)
              :to-equal "printf ok")
      (signals error
        (set-format-command "   " state))))

  (it "requires a formatter before enabling and supports toggling"
    (let ((state (%fresh-editor-state "text")))
      (signals error
        (format-on-save-mode t state))
      (set-format-command "cat" state)
      (expect (format-on-save-mode t state) :to-be-truthy)
      (expect (editor-state-format-on-save-p state) :to-be-truthy)
      (expect (format-on-save-mode nil state) :to-be-falsy)
      (expect (editor-state-format-on-save-p state) :to-be-falsy)
      (let ((*editor-state* state))
        (expect (format-on-save-mode) :to-be-truthy))))

  (it "rejects formatter configuration without an editor state"
    (signals error
      (set-format-command "cat" nil))
    (signals error
      (format-on-save-mode t nil)))

  (it "reports formatter failures during save without aborting the save"
    (%with-minibuffer-state (minibuffer "text")
      (let ((state *editor-state*)
            (buffer (%selected-test-buffer)))
        (set-format-command "printf error >&2; exit 7" state)
        (format-on-save-mode t state)
        (expect (format-before-save buffer state) :to-be buffer)
        (expect (buffer-text buffer) :to-equal "text")
        (expect (minibuffer-message-string minibuffer)
                :to-equal "Format-on-save exited with code 7")))))

(describe
  "format command prompts"
  (it "reports cancellation for an empty formatter prompt"
    (%with-minibuffer-state (minibuffer "text")
      (format-current-buffer)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "  ")
      (expect (minibuffer-message-string minibuffer)
              :to-equal "Format command cancelled")))

  (it "stores a formatter configured through its command"
    (%with-minibuffer-state (minibuffer "text")
      (set-format-command-command)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "  cat  ")
      (expect (editor-state-format-command *editor-state*)
              :to-equal "cat")
      (expect (minibuffer-message-string minibuffer)
              :to-equal "Format-on-save command set")))

  (it "reports invalid formatter configuration from its command"
    (%with-minibuffer-state (minibuffer "text")
      (set-format-command-command)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "  ")
      (expect (minibuffer-message-string minibuffer)
              :to-contain "Format-on-save command error:"))))
