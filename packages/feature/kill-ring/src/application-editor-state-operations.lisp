(in-package #:loom)

(defun %clear-last-yank ()
  (editor-state-clear-last-yank *editor-state*))
