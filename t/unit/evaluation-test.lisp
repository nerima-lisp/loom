(in-package #:loom/test)

(describe
  "evaluate-lisp-source"
  (it "captures values and standard output"
    (let ((result (loom:evaluate-lisp-source
                   "(format t \"hello~%\") (+ 1 2)")))
      (expect (loom:evaluation-result-form-count result) :to-equal 2)
      (expect (loom:evaluation-result-value-lines result)
              :to-equal '("NIL" "3"))
      (expect (loom:evaluation-result-output result)
              :to-equal (format nil "hello~%"))
      (expect (loom:evaluation-result-success-p result) :to-be-truthy)
      (expect (loom:evaluation-result-text result)
              :to-equal (format nil "=> NIL~%=> 3~%Output:~%hello~%"))))
  (it "captures evaluation errors without losing earlier values"
    (let ((result (loom:evaluate-lisp-source
                   "(values :before) (error \"boom\")")))
      (expect (loom:evaluation-result-form-count result) :to-equal 2)
      (expect (loom:evaluation-result-value-lines result)
              :to-equal '(":BEFORE"))
      (expect (loom:evaluation-result-success-p result) :to-be-falsy)
      (expect (loom:evaluation-result-error-message result)
              :to-equal "boom")
      (expect (loom:evaluation-result-text result)
              :to-equal (format nil "=> :BEFORE~%Evaluation error: boom~%"))))
  (it "does not execute reader-eval syntax"
    (let ((result (loom:evaluate-lisp-source
                   "#.(+ 1 2)")))
      (expect (loom:evaluation-result-form-count result) :to-equal 0)
      (expect (loom:evaluation-result-success-p result) :to-be-falsy)
      (expect (loom:evaluation-result-error-message result)
              :to-contain "read"))))

(describe
  "evaluation commands"
  (it "evaluates the selected buffer into the result buffer"
    (let* ((state (%fresh-editor-state "(+ 2 3)" :with-minibuffer t))
           (source-buffer (window-buffer
                           (window-tree-selected-window
                            (editor-state-window-tree state)))))
      (let ((*editor-state* state))
        (loom::eval-buffer)
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
      (loom::eval-expression)
      (expect (minibuffer-prompt-string minibuffer) :to-equal "Eval: ")
      (funcall (loom::%minibuffer-on-confirm minibuffer) "(list :ok)")
      (let ((result (find "*Loom-Eval*"
                          (editor-state-buffers *editor-state*)
                          :key #'buffer-name
                          :test #'string=)))
        (expect result :to-be-truthy)
        (expect (buffer-text result)
                :to-equal (format nil "loom-eval> (list :ok)~%=> (:OK)~%~%")))))
