;;;; t/unit/buffer-redo-test.lisp
(in-package #:loom/test)

(describe
  "buffer-redo"
  (it
    "replays a single undone edit and is then exhausted"
    (let ((buffer (make-buffer :initial-content "hello")))
      (buffer-set-point buffer 0 5)
      (buffer-insert-string buffer "!")
      (buffer-undo buffer)
      (expect (buffer-line buffer 0) :to-equal "hello")
      (buffer-redo buffer)
      (expect (buffer-line buffer 0) :to-equal "hello!")
      (buffer-redo buffer)
      (expect (buffer-line buffer 0) :to-equal "hello!")))

  (it
    "replays a whole undo group in original edit order"
    (let ((buffer (make-buffer :initial-content "")))
      (buffer-insert-string buffer "a")
      (buffer-insert-string buffer "b")
      (buffer-undo buffer)
      (expect (buffer-line buffer 0) :to-equal "")
      (buffer-redo buffer)
      (expect (buffer-line buffer 0) :to-equal "ab")))

  (it
    "clears redo history after a new edit"
    (let ((buffer (make-buffer :initial-content "hello")))
      (buffer-set-point buffer 0 5)
      (buffer-insert-string buffer "!")
      (buffer-undo buffer)
      (buffer-insert-string buffer "?")
      (buffer-redo buffer)
      (expect (buffer-line buffer 0) :to-equal "hello?"))))
