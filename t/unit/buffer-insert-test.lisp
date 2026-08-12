;;;; t/unit/buffer-insert-test.lisp
(in-package #:loom/test)

(describe
  "buffer-insert-string"
  (it
    "inserts at point, moves point after the text, and marks modified"
    (let ((buffer (make-buffer :initial-content "hllo")))
      (buffer-set-point buffer 0 1)
      (buffer-insert-string buffer "e")
      (expect (buffer-line buffer 0) :to-equal "hello")
      (expect buffer :to-have-point (cons 0 2))
      (expect (buffer-modified-p buffer) :to-be-truthy)))

  (it
    "splits the buffer across a newline in the inserted text"
    (let ((buffer (make-buffer :initial-content "helloworld")))
      (buffer-set-point buffer 0 5)
      (buffer-insert-string buffer (format nil "~%"))
      (expect (buffer-line-count buffer) :to-equal 2)
      (expect (buffer-line buffer 0) :to-equal "hello")
      (expect (buffer-line buffer 1) :to-equal "world")
      (expect buffer :to-have-point (cons 1 0))))

  (it
    "single-line insert on a non-first line of a multi-line buffer leaves other lines untouched"
    (let ((buffer (make-buffer :initial-content (format nil "one~%hllo~%three"))))
      (buffer-set-point buffer 1 1)
      (buffer-insert-string buffer "e")
      (expect (buffer-line-count buffer) :to-equal 3)
      (expect (buffer-line buffer 0) :to-equal "one")
      (expect (buffer-line buffer 1) :to-equal "hello")
      (expect (buffer-line buffer 2) :to-equal "three")
      (expect buffer :to-have-point (cons 1 2))))

  (it
    "is a no-op for an empty string, leaving point and modified-p unchanged"
    (let ((buffer (make-buffer :initial-content "hello")))
      (buffer-set-point buffer 0 2)
      (buffer-insert-string buffer "")
      (expect (buffer-line buffer 0) :to-equal "hello")
      (expect buffer :to-have-point (cons 0 2))
      (expect (buffer-modified-p buffer) :to-be-falsy))))
