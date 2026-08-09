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

(defun %repeat-command (count forward backward)
  (let ((command (if (minusp count) backward forward)))
    (loop repeat (abs count)
          do (funcall command))))

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

(defun prefix-argument-action (descriptor argument)
  "Return the pending prefix action for DESCRIPTOR, or NIL.

The dispatcher uses this single-value representation so that an action whose
VALUE is NIL (universal argument and sign toggling) remains distinguishable
from an ordinary key that is not a prefix action."
  (multiple-value-bind (kind value)
      (%prefix-argument-descriptor-action descriptor argument)
    (and kind (cons kind value))))

(defun apply-prefix-argument-action (kind value)
  (let ((argument (prefix-argument-for-editor)))
    (case kind
      (:universal (prefix-argument-universal argument))
      (:digit (prefix-argument-digit argument value))
      (:negative (prefix-argument-negative argument))
      (otherwise (error "Unknown prefix argument action: ~S" kind)))))

(defun prefix-argument-value-for-editor ()
  (prefix-argument-value (prefix-argument-for-editor)))

(defun consume-prefix-argument-for-editor ()
  (prefix-argument-consume (prefix-argument-for-editor)))

(defun universal-argument ()
  (apply-prefix-argument-action :universal nil)
  (minibuffer-message (editor-state-minibuffer *editor-state*)
                      (format nil "Prefix argument: ~D"
                              (prefix-argument-value-for-editor))))
