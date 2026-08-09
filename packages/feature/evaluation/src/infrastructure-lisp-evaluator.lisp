(in-package #:loom)

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
        (error-message nil)
        (eof (gensym "EOF")))
    (handler-case
        (let ((*package* (%loom-evaluation-package))
              (*read-eval* nil)
              (*standard-output* output-stream)
              (*error-output* error-stream))
          (with-input-from-string (input source)
            (loop for form = (read input nil eof)
                  until (eq form eof)
                  do (incf form-count)
                     (push (%evaluation-values-line
                            (multiple-value-list (eval form)))
                           value-lines))))
      (error (condition)
        (setf error-message (princ-to-string condition))))
    (make-evaluation-result
     :form-count form-count
     :value-lines (nreverse value-lines)
     :output (get-output-stream-string output-stream)
     :error-output (get-output-stream-string error-stream)
     :error-message error-message)))
