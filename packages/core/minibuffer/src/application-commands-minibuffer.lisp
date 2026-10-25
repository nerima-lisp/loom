(in-package #:loom)

(defun keyboard-quit ()
  "Report a Quit message (C-g)."
  (prefix-argument-reset (prefix-argument-for-editor))
  (minibuffer-message (editor-state-minibuffer *editor-state*) "Quit"))
