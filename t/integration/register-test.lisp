(in-package #:loom/test)

(describe
  "register commands"
  (it
    "copies a region and inserts it through minibuffer prompts"
    (%with-minibuffer-state
        (minibuffer "hello"
                    (buffer (%selected-test-buffer)))
      (buffer-set-point buffer 0 5)
      (buffer-set-mark buffer 0 0)
      (loom::copy-to-register)
      (expect (minibuffer-prompt-string minibuffer)
              :to-equal "Copy region to register: ")
      (funcall (loom::%minibuffer-on-confirm minibuffer) "a")
      (expect (register-bank-text (editor-state-registers *editor-state*) #\a)
              :to-equal "hello")
      (loom::insert-register)
      (expect (minibuffer-prompt-string minibuffer)
              :to-equal "Insert register: ")
      (funcall (loom::%minibuffer-on-confirm minibuffer) "a")
      (expect (buffer-text buffer) :to-equal "hellohello")))

  (it
    "stores and jumps to a point through a position register"
    (%with-minibuffer-state
        (minibuffer "hello"
                    (buffer (%selected-test-buffer)))
      (buffer-set-point buffer 0 3)
      (loom::point-to-register)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "p")
      (buffer-set-point buffer 0 0)
      (loom::jump-to-register)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "p")
      (expect buffer :to-have-point (cons 0 3))))

  (it
    "reports missing marks and missing registers"
    (%with-minibuffer-state
        (minibuffer "hello"
                    (buffer (%selected-test-buffer)))
      (loom::copy-to-register)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "a")
      (expect (loom::%minibuffer-message minibuffer)
              :to-equal "The mark is not set")
      (loom::insert-register)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "b")
      (expect (loom::%minibuffer-message minibuffer)
              :to-equal "Register b does not contain text"))))
