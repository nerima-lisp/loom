;;;; t/integration/editor-flow-test.lisp
;;;;
;;;; Exercise the application keymap against a disk-backed buffer. This is
;;;; intentionally broader than a command unit test: input dispatch, buffer
;;;; mutation, and the save command must agree on the same editor state.
(in-package #:loom/test)

(describe
  "editor file workflow"
  (it
    "inserts text and saves it through the default C-x C-s binding"
    (host-kit:with-temporary-directory (directory)
      (let ((path (merge-pathnames "notes.txt" directory)))
        (host-kit:write-file-string "before" path)
        (let* ((buffer (buffer-load path))
               (keymap (loom/application:install-default-keybindings (make-keymap)))
               (state (make-editor-state
                       :window-tree (make-window-tree buffer 80 24)
                       :minibuffer (make-minibuffer)
                       :keymap keymap
                       :file-tree nil
                       :renderer nil
                       :buffers (list buffer)
                       :kill-ring nil))
               (*editor-state* state)
               (keymap-state (make-keymap-state keymap)))
          (buffer-set-point buffer 0 0)
          (loom::%dispatch-key-event
           (cl-tty-kit:make-key-event :type :character :code #\!)
           keymap-state)
          (loom::%dispatch-key-event
           (cl-tty-kit:make-key-event :type :character :code #\x :modifiers '(:control))
           keymap-state)
          (loom::%dispatch-key-event
           (cl-tty-kit:make-key-event :type :character :code #\s :modifiers '(:control))
           keymap-state)
          (expect (buffer-text buffer) :to-equal "!before")
          (expect (host-kit:read-file-string path) :to-equal "!before")
          (expect (buffer-modified-p buffer) :to-be nil))))))
