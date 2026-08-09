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
      (loom/feature/register:copy-to-register)
      (expect (minibuffer-prompt-string minibuffer)
              :to-equal "Copy region to register: ")
      (funcall (loom::%minibuffer-on-confirm minibuffer) "a")
      (expect (register-bank-text (editor-state-registers *editor-state*) #\a)
              :to-equal "hello")
      (loom/feature/register:insert-register)
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
      (loom/feature/register:point-to-register)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "p")
      (buffer-set-point buffer 0 0)
      (loom/feature/register:jump-to-register)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "p")
      (expect buffer :to-have-point (cons 0 3))))

  (it
    "reports missing marks and missing registers"
    (%with-minibuffer-state
        (minibuffer "hello")
      (loom/feature/register:copy-to-register)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "a")
      (expect (loom::%minibuffer-message minibuffer)
              :to-equal "The mark is not set")
      (loom/feature/register:insert-register)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "b")
      (expect (loom::%minibuffer-message minibuffer)
              :to-equal "Register b does not contain text")))

  (it
    "reports invalid names and missing register positions"
    (%with-minibuffer-state
        (minibuffer "hello")
      (loom/feature/register:copy-to-register)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "ab")
      (expect (loom::%minibuffer-message minibuffer)
              :to-equal
              "Register name must be exactly one character")

      (loom/feature/register:insert-register)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "")
      (expect (loom::%minibuffer-message minibuffer)
              :to-equal
              "Register name must be exactly one character")

      (loom/feature/register:point-to-register)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "ab")
      (expect (loom::%minibuffer-message minibuffer)
              :to-equal
              "Register name must be exactly one character")

      (loom/feature/register:jump-to-register)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "ab")
      (expect (loom::%minibuffer-message minibuffer)
              :to-equal
              "Register name must be exactly one character")

      (loom/feature/register:jump-to-register)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "z")
      (expect (loom::%minibuffer-message minibuffer)
              :to-equal
              "Register z does not contain a position"))))
