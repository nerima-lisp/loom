;;;; t/integration/main-test-support.lisp
(in-package #:loom/test)

(defun %fresh-full-editor-state (initial-content)
  "Build a complete *EDITOR-STATE*, unlike %FRESH-EDITOR-STATE in
commands-test.lisp: a real minibuffer, file-tree, renderer, and the default
keybindings, for exercising %RUN-EVENT-LOOP end to end."
  (let* ((buffer (make-buffer :initial-content initial-content))
         (window-tree (make-window-tree buffer 80 24)))
    (make-editor-state :window-tree window-tree
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
