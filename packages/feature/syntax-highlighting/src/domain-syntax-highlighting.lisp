;;;; packages/feature/syntax-highlighting/src/domain-syntax-highlighting.lisp
;;;;
;;;; Line-local Common Lisp lexical classification.  This module returns
;;;; semantic tokens without depending on terminal or rendering packages.

(in-package #:loom/feature/syntax-highlighting)

(defstruct (syntax-token
            (:constructor %make-syntax-token (kind text))
            (:copier nil))
  "A semantic token from a single source line."
  kind
  text)

(defparameter +syntax-lisp-keywords+
  '("and" "block" "case" "catch" "cond" "declare" "defclass" "defconstant"
    "defgeneric" "define-condition" "defmacro" "defmethod" "defpackage"
    "defparameter" "defsetf" "defstruct" "deftype" "defun" "defvar" "do"
    "dolist" "dotimes" "ecase" "etypecase" "eval-when" "flet" "function"
    "handler-bind" "handler-case" "if" "labels" "lambda" "let" "let*"
    "loop" "macrolet" "multiple-value-bind" "multiple-value-call"
    "multiple-value-prog1" "multiple-value-setq" "nil" "or" "otherwise"
    "prog" "prog1" "progn" "progv" "quote" "return" "return-from" "setf"
    "tagbody" "the" "throw" "typecase" "unless" "unwind-protect" "when"
    "with-open-file" "with-output-to-string" "with-slots"
    "with-standard-io-syntax" "write" "t")
  "Common Lisp forms that receive the keyword token category.")

(defun %syntax-whitespace-p (character)
  (member character '(#\Space #\Tab #\Page #\Return #\Newline) :test #'char=))

(defun %syntax-whitespace-end (line start)
  (let ((position start))
    (loop while (and (< position (length line))
                     (%syntax-whitespace-p (char line position)))
          do (incf position))
    position))

(defun %syntax-string-end (line start)
  (let ((escaped nil))
    (loop for position from (1+ start) below (length line)
          for character = (char line position)
          do (cond (escaped
                    (setf escaped nil))
                   ((char= character #\\)
                    (setf escaped t))
                   ((char= character #\")
                    (return (1+ position))))
          finally (return (length line)))))

(defun %syntax-number-start-position (text)
  (if (and (> (length text) 1)
           (find (char text 0) '(#\+ #\-) :test #'char=))
      1
      0))

(defun %syntax-number-body-p (text start)
  (let ((position start)
        (digits 0)
        (dot-seen nil))
    (loop while (< position (length text))
          for character = (char text position)
          do (cond ((digit-char-p character 10)
                    (incf digits)
                    (incf position))
                   ((and (not dot-seen) (char= character #\.))
                    (setf dot-seen t)
                    (incf position))
                   (t (return))))
    (and (plusp digits)
         (= position (length text)))))

(defun %syntax-number-token-p (text)
  (%syntax-number-body-p text (%syntax-number-start-position text)))
