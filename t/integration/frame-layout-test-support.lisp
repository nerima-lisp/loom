
(in-package #:loom/test)

(defun %fresh-layout-state (&key name
                            (content "")
                            (width 40)
                            (height 6)
                            (renderer-width width)
                            (renderer-height height)
                            additional-slices)
  "Build the editor state shared by layout and frame integration tests."
  (let* ((buffer (make-buffer :name name :initial-content content))
         (window-tree (make-window-tree buffer width height)))
    (make-editor-state :window-tree window-tree
                       :session (%make-test-editor-session
                        (list buffer)
                        :window-tree window-tree
                        :additional-slices additional-slices)
                       :minibuffer (make-minibuffer)
                       :keymap (make-keymap)
                       :file-tree (make-file-tree "/root/")
                       :renderer (make-loom-renderer renderer-width renderer-height)
                       :kill-ring nil)))

(defun %layout-screen (state)
  "Return the terminal screen rendered by STATE."
  (cl-tty-kit:renderer-screen
   (loom::%loom-renderer-cl-tty-renderer (editor-state-renderer state))))

(defun %layout-window (state)
  "Return STATE's selected window."
  (window-tree-selected-window (editor-state-window-tree state)))

(defmacro with-layout-state ((name &rest initargs) &body body)
  "Run BODY with NAME bound to a fresh layout test state."
  `(let ((,name (%fresh-layout-state ,@initargs)))
     ,@body))
