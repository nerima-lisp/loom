;;;; t/unit/minibuffer-input-completion-test.lisp
;;;;
;;;; Completion behavior for src/application/minibuffer-input.lisp.
(in-package #:loom/test)

(describe
  "minibuffer completion"
  (it
    "passes current input to the completion function and completes a unique candidate"
    (let ((seen nil)
          (minibuffer (make-minibuffer)))
      (minibuffer-activate
       minibuffer "M-x "
       :completion-function
       (lambda (input)
         (setf seen input)
         '("forward-char" "forward-word" "backward-char")))
      (%type-string minibuffer "forward-c")
      (minibuffer-handle-key minibuffer (%special-key :tab))
      (expect seen :to-equal "forward-c")
      (expect (minibuffer-input-string minibuffer) :to-equal "forward-char")))

  (it
    "uses the longest common prefix for multiple matches"
    (let ((minibuffer (make-minibuffer)))
      (minibuffer-activate
       minibuffer "Prompt: "
       :completion-function
       (lambda (input)
         (declare (ignore input))
         '("alpha-one" "alpha-two")))
      (%type-string minibuffer "a")
      (minibuffer-handle-key minibuffer (%special-key :tab))
      (expect (minibuffer-input-string minibuffer) :to-equal "alpha-")))

  (it
    "leaves input unchanged when no candidate matches"
    (let ((minibuffer (make-minibuffer)))
      (minibuffer-activate
       minibuffer "Prompt: "
       :completion-function
       (lambda (input)
         (declare (ignore input))
         '("alpha")))
      (%type-string minibuffer "z")
      (minibuffer-handle-key minibuffer (%special-key :tab))
      (expect (minibuffer-input-string minibuffer) :to-equal "z")))

  (it
    "rejects invalid completion functions and candidate results"
    (let ((minibuffer (make-minibuffer)))
      (signals error
        (minibuffer-activate minibuffer "Prompt: " :completion-function 42))
      (minibuffer-activate
       minibuffer "Prompt: "
       :completion-function
       (lambda (input)
         (declare (ignore input))
         42))
      (signals error (minibuffer-complete minibuffer))
      (minibuffer-activate
       minibuffer "Prompt: "
       :completion-function
       (lambda (input)
         (declare (ignore input))
         '("valid" 42)))
      (signals error (minibuffer-complete minibuffer)))))
