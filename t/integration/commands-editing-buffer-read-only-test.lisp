;;;; t/integration/commands-editing-buffer-read-only-test.lisp
;;;;
;;;; Read-only command integration tests.
(in-package #:loom/test)

(describe
  "toggle-read-only"
  (it
    "toggles the selected buffer's mutation state"
    (%with-selected-minibuffer-buffer (minibuffer buffer "hello")
      (declare (ignore minibuffer))
      (expect (buffer-read-only-p buffer) :to-be-falsy)
      (expect (loom::toggle-read-only) :to-be buffer)
      (expect (buffer-read-only-p buffer) :to-be-truthy)
      (signals buffer-read-only-error
        (buffer-insert-string buffer "!"))
      (expect (loom::toggle-read-only) :to-be buffer)
      (expect (buffer-read-only-p buffer) :to-be-falsy)
      (buffer-set-point buffer 0 5)
      (buffer-insert-string buffer "!")
      (expect (buffer-text buffer) :to-equal "hello!"))))
