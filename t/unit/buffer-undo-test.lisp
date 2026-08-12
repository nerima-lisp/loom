;;;; t/unit/buffer-undo-test.lisp
(in-package #:loom/test)

(describe
  "buffer-undo"
  (it
    "undoes a single insert back to the prior text"
    (let ((buffer (make-buffer :initial-content "hello")))
      (buffer-set-point buffer 0 5)
      (buffer-insert-string buffer " world")
      (expect (buffer-line buffer 0) :to-equal "hello world")
      (buffer-undo buffer)
      (expect (buffer-line buffer 0) :to-equal "hello")
      (expect (buffer-point-column buffer) :to-equal 5)))

  (it
    "undoes a delete by re-inserting the deleted text"
    (let ((buffer (make-buffer :initial-content "hello world")))
      (buffer-delete-region buffer 0 5 0 11)
      (expect (buffer-line buffer 0) :to-equal "hello")
      (buffer-undo buffer)
      (expect (buffer-line buffer 0) :to-equal "hello world")))

  (it
    "a boundary excludes earlier edits from the next undo's group"
    (let ((buffer (make-buffer :initial-content "")))
      (buffer-insert-string buffer "a")
      (buffer-insert-string buffer "b")
      (buffer-record-undo-boundary buffer)
      (buffer-insert-string buffer "c")
      (expect (buffer-line buffer 0) :to-equal "abc")
      (buffer-undo buffer)
      (expect (buffer-line buffer 0) :to-equal "ab")))

  (it
    "a second consecutive call does not push a duplicate boundary marker"
    (let ((buffer (make-buffer :initial-content "")))
      (buffer-insert-string buffer "a")
      (buffer-record-undo-boundary buffer)
      (buffer-record-undo-boundary buffer)
      (buffer-insert-string buffer "b")
      (expect (buffer-line buffer 0) :to-equal "ab")
      (buffer-undo buffer)
      (expect (buffer-line buffer 0) :to-equal "a")))

  (it
    "is a no-op once history is exhausted"
    (let ((buffer (make-buffer :initial-content "x")))
      (buffer-undo buffer)
      (expect (buffer-line buffer 0) :to-equal "x")))

  (it
    "walks forward through its own inverse on a second undo, ring-style"
    (let ((buffer (make-buffer :initial-content "hello")))
      (buffer-set-point buffer 0 5)
      (buffer-insert-string buffer "!")
      (expect (buffer-line buffer 0) :to-equal "hello!")
      (buffer-undo buffer)
      (expect (buffer-line buffer 0) :to-equal "hello")
      (buffer-undo buffer)
      (expect (buffer-line buffer 0) :to-equal "hello!"))))
