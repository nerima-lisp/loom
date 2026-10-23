(in-package #:loom/core/command)

(defvar *current-prefix-argument* nil)

(defun repeat-command (forward backward)
  "Run a one-step callback according to the dynamically bound prefix."
  (let* ((count (or *current-prefix-argument* 1))
         (operation (if (minusp count) backward forward)))
    (loop repeat (abs count)
          do (funcall operation))))
