;;;; packages/feature/session/src/domain-session-predicates.lisp
(in-package #:loom/feature/session)

(defun %session-nonnegative-integer-p (value)
  (and (integerp value) (<= 0 value)))

(defun %session-nonempty-string-p (value)
  (and (stringp value)
       (plusp (length value))))

(defun %session-optional-string-p (value)
  (or (null value)
      (%session-nonempty-string-p value)))

(defun %session-mark-valid-p (line column)
  (or (not (or line column))
      (and (%session-nonnegative-integer-p line)
           (%session-nonnegative-integer-p column))))
