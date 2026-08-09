(in-package #:loom/test)

(describe
  "evaluate-lisp-source"
  (it "captures values and standard output"
    (let ((result (loom/feature/evaluation:evaluate-lisp-source
                   "(format t \"hello~%\") (+ 1 2)")))
      (expect (loom/feature/evaluation:evaluation-result-form-count result) :to-equal 2)
      (expect (loom/feature/evaluation:evaluation-result-value-lines result)
              :to-equal '("NIL" "3"))
      (expect (loom/feature/evaluation:evaluation-result-output result)
              :to-equal (format nil "hello~%"))
      (expect (loom/feature/evaluation:evaluation-result-success-p result) :to-be-truthy)
      (expect (loom/feature/evaluation:evaluation-result-text result)
              :to-equal (format nil "=> NIL~%=> 3~%Output:~%hello~%"))))
  (it "captures evaluation errors without losing earlier values"
    (let ((result (loom/feature/evaluation:evaluate-lisp-source
                   "(values :before) (error \"boom\")")))
      (expect (loom/feature/evaluation:evaluation-result-form-count result) :to-equal 2)
      (expect (loom/feature/evaluation:evaluation-result-value-lines result)
              :to-equal '(":BEFORE"))
      (expect (loom/feature/evaluation:evaluation-result-success-p result) :to-be-falsy)
      (expect (loom/feature/evaluation:evaluation-result-error-message result)
              :to-equal "boom")
      (expect (loom/feature/evaluation:evaluation-result-text result)
              :to-equal (format nil "=> :BEFORE~%Evaluation error: boom~%"))))
  (it "does not execute reader-eval syntax"
    (let ((result (loom/feature/evaluation:evaluate-lisp-source
                   "#.(+ 1 2)")))
      (expect (loom/feature/evaluation:evaluation-result-form-count result) :to-equal 0)
      (expect (loom/feature/evaluation:evaluation-result-success-p result) :to-be-falsy)
      (expect (loom/feature/evaluation:evaluation-result-error-message result)
              :to-contain "read"))))

(describe
  "evaluation commands"
  (it "evaluates the selected buffer into the result buffer"
    (let* ((state (%fresh-editor-state "(+ 2 3)" :with-minibuffer t))
           (source-buffer (window-buffer
                           (window-tree-selected-window
                            (editor-state-window-tree state)))))
      (let ((*editor-state* state))
        (loom/feature/evaluation:eval-buffer)
        (let ((result (find "*Loom-Eval*"
                            (editor-state-buffers state)
                            :key #'buffer-name
                            :test #'string=)))
          (expect result :to-be-truthy)
          (expect (buffer-text result)
                  :to-equal (format nil "loom-eval> (+ 2 3)~%=> 5~%~%"))
          (expect (buffer-modified-p result) :to-be nil)
          (expect (window-buffer
                   (window-tree-selected-window
                    (editor-state-window-tree state)))
                  :to-be result)
          (expect (window-buffer
                   (window-tree-selected-window
                    (editor-state-window-tree state)))
                  :not :to-be source-buffer))))))
  (it "evaluates minibuffer input"
    (%with-minibuffer-state (minibuffer "")
      (loom/feature/evaluation:eval-expression)
      (expect (minibuffer-prompt-string minibuffer) :to-equal "Eval: ")
      (funcall (loom::%minibuffer-on-confirm minibuffer) "(list :ok)")
      (let ((result (find "*Loom-Eval*"
                          (editor-state-buffers *editor-state*)
                          :key #'buffer-name
                          :test #'string=)))
        (expect result :to-be-truthy)
        (expect (buffer-text result)
                :to-equal (format nil "loom-eval> (list :ok)~%=> (:OK)~%~%")))))

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
                      "=> 42~%Output:~%stdout~%Error output:~%stderr~%Evaluation error: boom~%"))))

  (it "rejects empty minibuffer evaluation input"
    (%with-minibuffer-state (minibuffer "")
      (eval-expression)
      (expect (minibuffer-prompt-string minibuffer) :to-equal "Eval: ")
      (funcall (loom::%minibuffer-on-confirm minibuffer) "   ")
      (expect (loom::%minibuffer-message minibuffer)
              :to-equal "Evaluation source cannot be empty")))

  (it "reports evaluation errors through the command result"
    (%with-minibuffer-state (minibuffer "")
      (eval-expression)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "(error \"command boom\")")
      (let ((result (find "*Loom-Eval*"
                          (editor-state-buffers *editor-state*)
                          :key #'buffer-name
                          :test #'string=)))
        (expect result :to-be-truthy)
        (expect (buffer-text result)
                :to-contain "Evaluation error: command boom")
        (expect (loom::%minibuffer-message minibuffer)
                :to-equal "Evaluation error: command boom"))))
