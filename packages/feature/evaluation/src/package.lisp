(defpackage #:loom/feature/evaluation
  (:use #:cl #:loom #:loom/application #:loom/feature/window)
  (:export
   #:evaluation-result
   #:make-evaluation-result
   #:evaluation-result-p
   #:evaluation-result-form-count
   #:evaluation-result-value-lines
   #:evaluation-result-output
   #:evaluation-result-error-output
   #:evaluation-result-error-message
   #:evaluation-result-success-p
   #:evaluation-result-text
   #:evaluate-lisp-source
   #:eval-expression
   #:eval-buffer))
