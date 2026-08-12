(in-package #:loom/test)

(describe
  "evaluation result rendering"
  (it "reports empty and multi-value evaluation results"
    (let ((empty (make-evaluation-result)))
      (expect (evaluation-result-text empty)
              :to-equal (format nil "No forms evaluated.~%")))
    (let ((result (evaluate-lisp-source "(values)")))
      (expect (evaluation-result-value-lines result)
              :to-equal '("<no values>"))
      (expect (evaluation-result-form-count result) :to-equal 1))
    (let ((result (evaluate-lisp-source "(values 1 2)")))
      (expect (evaluation-result-value-lines result)
              :to-equal '("1, 2"))
      (expect (evaluation-result-form-count result) :to-equal 1)))

  (it "renders output and error output without requiring trailing newlines"
    (let ((result
            (make-evaluation-result
             :form-count 1
             :value-lines '("42")
             :output "stdout"
             :error-output "stderr"
             :error-message "boom")))
      (expect (evaluation-result-text result)
              :to-equal
              (format nil
                      "=> 42~%Output:~%stdout~%Error output:~%stderr~%Evaluation error: boom~%")))))
