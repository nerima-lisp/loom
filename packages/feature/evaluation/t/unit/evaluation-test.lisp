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
              :to-contain "read")))
  (it "evaluates only the last complete form when requested"
    (multiple-value-bind (result selected-source)
        (loom/feature/evaluation:evaluate-lisp-source
         "(+ 1 2) (+ 3 4) (+ 5 6)" :last-expression-only t)
      (expect selected-source :to-equal "(+ 5 6)")
      (expect (loom/feature/evaluation:evaluation-result-form-count result) :to-equal 1)
      (expect (loom/feature/evaluation:evaluation-result-value-lines result)
              :to-equal '("11"))))
  (it "returns malformed input for the evaluation error path"
    (multiple-value-bind (result selected-source)
        (loom/feature/evaluation:evaluate-lisp-source
         "(+ 1 2) (incomplete" :last-expression-only t)
      (expect selected-source :to-equal "(incomplete")
      (expect (loom/feature/evaluation:evaluation-result-success-p result)
              :to-be-falsy))))
(describe
  "eval-last-sexp"
  (it "displays the last sexp value in the minibuffer and preserves source state"
    (let* ((state (%fresh-editor-state "(+ 1 2) (+ 3 4) (+ 5 6)" :with-minibuffer t))
           (source-buffer (window-buffer
                           (window-tree-selected-window
                            (editor-state-window-tree state))))
           (minibuffer (editor-state-minibuffer state)))
      (loom/core/buffer:buffer-set-point source-buffer 0 15)
      (let ((*editor-state* state)
            (loom/core/editor-session:*editor-session*
              (loom/core/editor-session:editor-state-session state)))
        (loom/feature/evaluation:eval-last-sexp)
        (expect (loom:minibuffer-message-string minibuffer)
                :to-equal "7 (#o7, #x7, ?\\C-g)")
        (expect (loom/core/buffer:buffer-point-offset source-buffer) :to-equal 15)
        (expect (buffer-text source-buffer) :to-equal "(+ 1 2) (+ 3 4) (+ 5 6)")
        (expect (window-buffer
                 (window-tree-selected-window
                  (editor-state-window-tree state)))
                :to-be source-buffer)))))

(describe
  "evaluation commands"
  (it "keeps the source buffer after evaluation without reporting a form count"
    (let* ((state (%fresh-editor-state "(+ 2 3)" :with-minibuffer t))
           (source-buffer (window-buffer
                           (window-tree-selected-window
                            (editor-state-window-tree state))))
           (minibuffer (editor-state-minibuffer state)))
      (loom/core/buffer:buffer-set-point source-buffer 0 2)
      (let ((*editor-state* state)
            (loom/core/editor-session:*editor-session*
              (loom/core/editor-session:editor-state-session state)))
        (loom/feature/evaluation:eval-buffer)
        (expect (buffer-text source-buffer) :to-equal "(+ 2 3)")
        (expect (loom/core/buffer:buffer-point-offset source-buffer) :to-equal 2)
        (expect (window-buffer
                 (window-tree-selected-window
                  (editor-state-window-tree state)))
                :to-be source-buffer)
        (expect (or (loom:minibuffer-message-string minibuffer) "") :to-equal "")))))
  (it "displays minibuffer evaluation values and preserves source state"
    (%with-minibuffer-state (minibuffer "source"
                                (source-buffer (%selected-test-buffer)))
      (loom/core/buffer:buffer-set-point source-buffer 0 2)
      (eval-expression)
      (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer) "(+ 1 2)")
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal "3 (#o3, #x3, ?\\C-c)")
      (expect (buffer-text source-buffer) :to-equal "source")
      (expect (loom/core/buffer:buffer-point-offset source-buffer) :to-equal 2)
      (expect (window-buffer
               (window-tree-selected-window
                (editor-state-window-tree *editor-state*)))
              :to-be source-buffer)))
  (it "reports Quit when cancelling an evaluation prompt"
    (%with-minibuffer-state (minibuffer "source"
                                (source-buffer (%selected-test-buffer)))
      (loom/core/buffer:buffer-set-point source-buffer 0 2)
      (eval-expression)
      (expect (minibuffer-active-p minibuffer) :to-be-truthy)
      (loom::keyboard-quit)
      (loom/core/minibuffer::%minibuffer-cancel minibuffer)
      (expect (minibuffer-active-p minibuffer) :to-be nil)
      (expect (loom:minibuffer-message-string minibuffer) :to-equal "Quit")
      (expect (buffer-text source-buffer) :to-equal "source")
      (expect (loom/core/buffer:buffer-point-offset source-buffer) :to-equal 2)
      (expect (window-buffer
               (window-tree-selected-window
                (editor-state-window-tree *editor-state*)))
              :to-be source-buffer)))
  (it "keeps an empty evaluation prompt active and reports the reader error"
    (%with-minibuffer-state (minibuffer "")
      (eval-expression)
      (expect (minibuffer-active-p minibuffer) :to-be-truthy)
      (expect (minibuffer-prompt-string minibuffer) :to-equal "Eval: ")
      (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer) "")
      (expect (minibuffer-active-p minibuffer) :to-be-truthy)
      (expect (minibuffer-prompt-string minibuffer)
              :to-equal "Eval: [End of file during parsing]")
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal "[End of file during parsing]")))

  (it "reports evaluation errors in the minibuffer and preserves source state"
    (%with-minibuffer-state (minibuffer "source"
                                (source-buffer (%selected-test-buffer)))
      (loom/core/buffer:buffer-set-point source-buffer 0 2)
      (eval-expression)
      (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer) "(error \"command boom\")")
      (expect (loom:minibuffer-message-string minibuffer)
              :to-contain "command boom")
      (expect (buffer-text source-buffer) :to-equal "source")
      (expect (loom/core/buffer:buffer-point-offset source-buffer) :to-equal 2)
      (expect (window-buffer
               (window-tree-selected-window
                (editor-state-window-tree *editor-state*)))
              :to-be source-buffer)
      (expect (find "*Loom-Eval*"
                    (%test-registered-buffers *editor-state*)
                    :key (function buffer-name)
                    :test (function string=))
              :to-be nil)))
