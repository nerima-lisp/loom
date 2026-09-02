(in-package #:loom)

(defvar *current-prefix-argument* nil)

(defun prefix-argument-for-editor ()
  (or (editor-state-prefix-argument *editor-state*)
      (setf (editor-state-prefix-argument *editor-state*)
            (make-prefix-argument))))

(defun %command-prefix-count ()
  (or *current-prefix-argument* 1))

(defmacro with-nonnegative-command-prefix ((count) &body body)
  `(let ((,count (max 0 (%command-prefix-count))))
     ,@body))

(defun %repeat-command (count forward backward)
  (let ((command (if (minusp count) backward forward)))
    (loop repeat (abs count)
          do (funcall command))))

(defmacro define-repeating-command (name documentation forward backward)
  "Define NAME as a prefix-aware FORWARD/BACKWARD command pair."
  `(defun ,name ()
     ,documentation
     (%repeat-command (%command-prefix-count)
                      #',forward
                      #',backward)))

(defun %universal-prefix-descriptor-p (modifiers code)
  (and (equal modifiers '(:control))
       (characterp code)
       (char-equal code #\u)))

(defun %alternate-prefix-descriptor-p (modifiers)
  (and (member :alt modifiers)
       (not (member :control modifiers))))

(defun %digit-prefix-descriptor-value (modifiers code active-p)
  (let ((digit (and (characterp code) (digit-char-p code)))
        (alt-p (%alternate-prefix-descriptor-p modifiers)))
    (when (and digit
               (or alt-p
                   (and active-p (null modifiers))))
      digit)))

(defun %negative-prefix-descriptor-p (modifiers code active-p)
  (let ((alt-p (%alternate-prefix-descriptor-p modifiers)))
    (and (characterp code)
         (char= code #\-)
         (or alt-p
             (and active-p (null modifiers))))))

(defun %prefix-action-kind (modifiers code active-p)
  (cond
    ((%universal-prefix-descriptor-p modifiers code)
     :universal)
    ((%digit-prefix-descriptor-value modifiers code active-p)
     :digit)
    ((%negative-prefix-descriptor-p modifiers code active-p)
     :negative)))

(defun %prefix-argument-descriptor-action (descriptor argument)
  (check-type argument prefix-argument)
  (let* ((normalized (normalize-key-descriptor descriptor))
         (modifiers (car normalized))
         (code (cdr normalized))
         (active-p (prefix-argument-active-p argument))
         (digit (%digit-prefix-descriptor-value modifiers code active-p)))
    (case (%prefix-action-kind modifiers code active-p)
      (:digit (values :digit digit))
      (:universal (values :universal nil))
      (:negative (values :negative nil))
      (otherwise (values nil nil)))))
