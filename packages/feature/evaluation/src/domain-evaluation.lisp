(in-package #:loom/feature/evaluation)

;;; Evaluation results are kept as a small domain value object so that the
;;; application and presentation layers do not need to know how Lisp was run.
(defstruct (evaluation-result
            (:constructor make-evaluation-result
                (&key (form-count 0)
                      (value-lines nil)
                      (output "")
                      (error-output "")
                      error-message))
            (:copier nil))
  form-count
  value-lines
  output
  error-output
  error-message)

(defun evaluation-result-success-p (result)
  "Return true when RESULT did not produce an evaluation error."
  (null (evaluation-result-error-message result)))

(defun %write-evaluation-stream (stream label text)
  (when (plusp (length text))
    (format stream "~A:~%" label)
    (write-string text stream)
    (unless (char= (char text (1- (length text))) #\Newline)
      (terpri stream))))

(defun evaluation-result-text (result)
  "Render RESULT as text suitable for the evaluation output buffer."
  (with-output-to-string (stream)
    (dolist (line (evaluation-result-value-lines result))
      (format stream "=> ~A~%" line))
    (%write-evaluation-stream stream
                              "Output"
                              (evaluation-result-output result))
    (%write-evaluation-stream stream
                              "Error output"
                              (evaluation-result-error-output result))
    (when (evaluation-result-error-message result)
      (format stream "Evaluation error: ~A~%"
              (evaluation-result-error-message result)))
    (when (and (zerop (evaluation-result-form-count result))
               (null (evaluation-result-error-message result))
               (zerop (length (evaluation-result-output result)))
               (zerop (length (evaluation-result-error-output result))))
      (write-string "No forms evaluated." stream)
      (terpri stream))))
