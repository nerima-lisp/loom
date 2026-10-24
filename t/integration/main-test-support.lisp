(in-package #:loom/test)

(defun %fresh-full-editor-state (initial-content)
  "Include a minibuffer, file-tree, renderer, and default keybindings so
event-loop tests can exercise input routing and frame composition together."
  (let* ((buffer (make-buffer :initial-content initial-content))
         (window-tree (make-window-tree buffer 80 24)))
    (make-editor-state :window-tree window-tree
                       :session (%make-test-editor-session (list buffer) :window-tree window-tree)
                       :minibuffer (make-minibuffer)
                       :keymap (loom/application:install-default-keybindings (make-keymap))
                       :file-tree (make-file-tree "/root/")
                       :renderer (make-loom-renderer 80 24)
                       :kill-ring nil)))

(defclass %eof-after-listen-stream
    (sb-gray:fundamental-binary-input-stream)
  ())

(defmethod sb-gray:stream-listen ((stream %eof-after-listen-stream))
  (declare (ignore stream))
  t)

(defmethod sb-gray:stream-read-byte ((stream %eof-after-listen-stream))
  (declare (ignore stream))
  :eof)
