;;;; t/unit/buffer-read-only-test.lisp
(in-package #:loom/test)

(describe
  "buffer read-only"
  (it
    "rejects text mutations and undo/redo without changing history"
    (let ((buffer (make-buffer :initial-content "hello")))
      (buffer-set-point buffer 0 5)
      (buffer-insert-string buffer "!")
      (buffer-undo buffer)
      (buffer-set-read-only buffer t)
      (expect (buffer-read-only-p buffer) :to-be-truthy)
      (signals buffer-read-only-error
        (buffer-insert-string buffer "x"))
      (signals buffer-read-only-error
        (buffer-delete-char buffer))
      (signals buffer-read-only-error
        (buffer-delete-region buffer 0 0 0 1))
      (signals buffer-read-only-error
        (buffer-undo buffer))
      (signals buffer-read-only-error
        (buffer-redo buffer))
      (expect (buffer-text buffer) :to-equal "hello")
      (buffer-set-read-only buffer nil)
      (buffer-redo buffer)
      (expect (buffer-text buffer) :to-equal "hello!"))))
