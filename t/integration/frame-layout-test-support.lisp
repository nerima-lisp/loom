;;;; t/integration/frame-layout-test-support.lisp

(in-package #:loom/test)

(defun %fresh-layout-state (&key name (content "") (width 40) (height 6)
                                 (renderer-width width) (renderer-height height))
  (make-editor-state :window-tree (make-window-tree
                                   (make-buffer :name name :initial-content content)
                                   width
                                   height)
                     :minibuffer (make-minibuffer)
                     :keymap (make-keymap)
                     :file-tree (make-file-tree "/root/")
                     :renderer (make-loom-renderer renderer-width renderer-height)
                     :kill-ring nil))

(defun %layout-screen (state)
  (cl-tty-kit:renderer-screen
   (loom::%loom-renderer-cl-tty-renderer (editor-state-renderer state))))

(defun %layout-window (state)
  (window-tree-selected-window (editor-state-window-tree state)))
