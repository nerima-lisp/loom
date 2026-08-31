(in-package #:loom)

(defvar *current-prefix-argument* nil)

(defun prefix-argument-for-editor ()
  (or (editor-state-prefix-argument *editor-state*)
      (setf (editor-state-prefix-argument *editor-state*)
            (make-prefix-argument))))

(defun %command-prefix-count ()
  (if (null *current-prefix-argument*)
      1
      *current-prefix-argument*))

(defmacro with-nonnegative-command-prefix ((count) &body body)
  `(let ((,count (max 0 (%command-prefix-count))))
     ,@body))

(defun %repeat-command (count forward backward)
  (let ((command (if (minusp count) backward forward)))
    (loop repeat (abs count)
          do (funcall command))))

(defmacro define-repeating-command (name forward backward documentation)
  "Define NAME as a prefix-aware FORWARD/BACKWARD command pair."
  `(defun ,name ()
     ,documentation
     (%repeat-command (%command-prefix-count)
                      #',forward
                      #',backward)))

(defun %prefix-argument-descriptor-action (descriptor argument)
  (check-type argument prefix-argument)
  (let* ((normalized (normalize-key-descriptor descriptor))
         (modifiers (car normalized))
         (code (cdr normalized))
         (active-p (prefix-argument-active-p argument))
         (alt-p (and (member :alt modifiers)
                     (not (member :control modifiers)))))
    (cond
      ((and (equal modifiers '(:control))
            (characterp code)
            (char-equal code #\u))
       (values :universal nil))
      ((and (characterp code)
            (digit-char-p code)
            (or alt-p
                (and active-p (null modifiers))))
       (values :digit (digit-char-p code)))
      ((and (characterp code)
            (char= code #\-)
            (or alt-p
                (and active-p (null modifiers))))
       (values :negative nil))
      (t
       (values nil nil)))))
