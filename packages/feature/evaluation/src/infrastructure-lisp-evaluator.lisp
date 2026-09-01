(in-package #:loom/feature/evaluation)

;;; Evaluation is intentionally trusted, just like loading the user's init
;;; file.  The infrastructure boundary owns reader/eval and stream capture;
;;; callers receive a domain value instead of a condition escaping the command.
(defun %loom-evaluation-package ()
  (or (find-package "LOOM-USER")
      (error "The LOOM-USER package is not available.")))

(defun %evaluation-values-line (values)
  (if (null values)
      "<no values>"
      (with-output-to-string (stream)
        (loop with first-p = t
              for value in values
              do (unless first-p
                   (write-string ", " stream))
                 (setf first-p nil)
                 (prin1 value stream)))))

(defun %evaluate-form (form)
  (%evaluation-values-line (multiple-value-list (eval form))))

(defun %evaluate-forms (source eof)
  (let ((form-count 0)
        (value-lines nil)
        (error-message nil))
    (handler-case
        (with-input-from-string (input source)
          (loop for form = (read input nil eof)
                until (eq form eof)
                do (incf form-count)
                   (push (%evaluate-form form) value-lines)))
      (error (condition)
        (setf error-message (princ-to-string condition))))
    (values form-count (nreverse value-lines) error-message)))

(defun %evaluate-lisp-forms (source output-stream)
  "Evaluate SOURCE forms and return count, values, and an optional error."
  (let ((form-count 0)
        (value-lines nil)
        (error-message nil))
    (handler-case
        (let ((*package* (%loom-evaluation-package))
              (*read-eval* nil)
              (*standard-output* output-stream)
              (eof (gensym "EOF")))
          (multiple-value-setq (form-count value-lines error-message)
            (%evaluate-forms source eof)))
      (error (condition)
        (setf error-message (princ-to-string condition))))
    (values form-count value-lines error-message)))

(defun evaluate-lisp-source (source)
  "Evaluate every form in SOURCE in LOOM-USER and return an evaluation result.

Reader and evaluation errors are captured in the returned result.  Reader
evaluation syntax such as #. is disabled, while the evaluated forms otherwise
run with the same trusted access as user initialization code."
  (check-type source string)
  (let ((output-stream (make-string-output-stream))
        (error-stream (make-string-output-stream))
        (form-count 0)
        (value-lines nil)
        (error-message nil))
    (let ((*error-output* error-stream))
      (multiple-value-setq (form-count value-lines error-message)
        (%evaluate-lisp-forms source output-stream)))
    (make-evaluation-result
     :form-count form-count
     :value-lines value-lines
     :output (get-output-stream-string output-stream)
     :error-output (get-output-stream-string error-stream)
     :error-message error-message)))
