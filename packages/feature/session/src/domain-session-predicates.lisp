;;;; packages/feature/session/src/domain-session-predicates.lisp
(in-package #:loom/feature/session)

(defmacro define-session-predicate (name lambda-list &body body)
  "Define a small domain predicate from declarative validation logic."
  `(defun ,name ,lambda-list
     ,@body))

(define-session-predicate %session-nonnegative-integer-p (value)
  (and (integerp value) (<= 0 value)))

(define-session-predicate %session-nonempty-string-p (value)
  (and (stringp value)
       (plusp (length value))))

(define-session-predicate %session-optional-string-p (value)
  (or (null value)
      (%session-nonempty-string-p value)))

(define-session-predicate %session-mark-valid-p (line column)
  (or (and (null line) (null column))
      (and (%session-nonnegative-integer-p line)
           (%session-nonnegative-integer-p column))))
