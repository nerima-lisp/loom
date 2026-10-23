(in-package #:loom)

(defun universal-argument ()
  (apply-prefix-argument-action :universal nil)
  (loom/core/minibuffer:minibuffer-message
   (loom/core/editor-session:editor-state-minibuffer
    loom/core/editor-session:*editor-state*)
   (format nil "Prefix argument: ~D" (prefix-argument-value-for-editor))))
