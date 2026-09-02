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
  (when (string/= text "")
    (format stream "~A:~%" label)
    (write-string text stream)
    (unless (char= (char text (1- (length text))) #\Newline)
      (terpri stream))))

(defun %write-evaluation-values (stream result)
  (dolist (line (evaluation-result-value-lines result))
    (format stream "=> ~A~%" line)))

(defun %evaluation-result-empty-p (result)
  (and (zerop (evaluation-result-form-count result))
       (null (evaluation-result-error-message result))
       (string= (evaluation-result-output result) "")
       (string= (evaluation-result-error-output result) "")))

(defun evaluation-result-text (result)
  "Render RESULT as text suitable for the evaluation output buffer."
  (with-output-to-string (stream)
    (%write-evaluation-values stream result)
    (%write-evaluation-stream stream
                              "Output"
                              (evaluation-result-output result))
    (%write-evaluation-stream stream
                              "Error output"
                              (evaluation-result-error-output result))
    (when (evaluation-result-error-message result)
      (format stream "Evaluation error: ~A~%"
              (evaluation-result-error-message result)))
    (when (%evaluation-result-empty-p result)
      (write-string "No forms evaluated." stream)
      (terpri stream))))
