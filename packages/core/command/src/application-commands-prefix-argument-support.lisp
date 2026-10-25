(in-package #:loom)

(defun %command-prefix-count ()
  (or loom/core/command:*current-prefix-argument* 1))

(defmacro with-nonnegative-command-prefix ((count) &body body)
  `(let ((,count (max 0 (%command-prefix-count))))
     ,@body))

(defun %repeat-command (count forward backward)
  (let ((command
         (if (minusp count)
             backward
             forward)))
    (loop repeat (abs count)
          do (funcall command))))

(defmacro define-repeating-command (name documentation forward backward)
  "Define NAME as a prefix-aware FORWARD/BACKWARD command pair."
  `(defun ,name ()
     ,documentation
     (%repeat-command (%command-prefix-count) #',forward #',backward)))
