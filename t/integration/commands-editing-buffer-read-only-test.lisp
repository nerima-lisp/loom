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
      (expect (loom::toggle-read-only) :to-be buffer)
      (expect (buffer-read-only-p buffer) :to-be-falsy))))
