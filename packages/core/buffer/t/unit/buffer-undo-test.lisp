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
    "undo of deletion leaves point at the Emacs deletion start"
    (let ((buffer (make-buffer :initial-content "hello world")))
      (buffer-set-point buffer 0 5)
      (buffer-delete-region buffer 0 5 0 11)
      (expect (buffer-line buffer 0) :to-equal "hello")
      (buffer-undo buffer)
      (expect (buffer-line buffer 0) :to-equal "hello world")
      (expect (buffer-point-column buffer) :to-equal 5)))

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
      (expect (buffer-line buffer 0) :to-equal "hello!")))
  (it
    "undo and redo restore point around a replacement group"
    (let ((buffer (make-buffer :initial-content "one two")))
      (buffer-set-point buffer 0 0)
      (buffer-delete-region buffer 0 0 0 3)
      (buffer-insert-string buffer "ONE")
      (expect (buffer-line buffer 0) :to-equal "ONE two")
      (expect (buffer-point-column buffer) :to-equal 3)
      (buffer-undo buffer)
      (expect (buffer-line buffer 0) :to-equal "one two")
      (expect (buffer-point-column buffer) :to-equal 0)
      (buffer-redo buffer)
      (expect (buffer-line buffer 0) :to-equal "ONE two")
      (expect (buffer-point-column buffer) :to-equal 3)))
  (it
    "restores deletion point like Emacs when undoing"
    ;; GNU Emacs 31.1 records point at the start, except when point is exactly
    ;; at the deletion end, where undo restores it after the inserted text.
    (dolist (point-case '((1 3) (3 3) (5 3) (7 7) (9 3)))
      (let ((buffer (make-buffer :initial-content "abcdefghij"))
            (point-column (first point-case))
            (expected-column (second point-case)))
        (buffer-set-point buffer 0 point-column)
        (buffer-delete-region buffer 0 3 0 7)
        (expect (buffer-line buffer 0) :to-equal "abchij")
        (buffer-undo buffer)
        (expect (buffer-line buffer 0) :to-equal "abcdefghij")
        (expect (buffer-point-column buffer) :to-equal expected-column)
        (buffer-redo buffer)
        (expect (buffer-line buffer 0) :to-equal "abchij")
        (expect (buffer-point-column buffer) :to-equal 3))))
  (it
    "does not treat same-position separate deletion and insertion as a replacement"
    (let ((buffer (make-buffer :initial-content "0123456789")))
      (buffer-set-point buffer 0 9)
      (buffer-delete-region buffer 0 3 0 7)
      (buffer-set-point buffer 0 3)
      (buffer-insert-string buffer "X")
      (expect (buffer-line buffer 0) :to-equal "012X789")
      (buffer-undo buffer)
      (expect (buffer-line buffer 0) :to-equal "0123456789")
      (expect (buffer-point-column buffer) :to-equal 3))))
