;;;; t/unit/buffer-region-test.lisp
(in-package #:loom/test)

(describe
  "buffer-delete-region / buffer-region-string"
  (it
    "returns the region text without mutating for buffer-region-string"
    (let ((buffer (make-buffer :initial-content (format nil "hello~%world"))))
      (expect (buffer-region-string buffer 0 1 1 3) :to-equal (format nil "ello~%wor"))
      (expect (buffer-line-count buffer) :to-equal 2)
      (expect (buffer-line buffer 0) :to-equal "hello")))

  (it
    "deletes the region, moves point to start, and returns the deleted text"
    (let ((buffer (make-buffer :initial-content (format nil "hello~%world"))))
      (let ((deleted (buffer-delete-region buffer 0 1 1 3)))
        (expect deleted :to-equal (format nil "ello~%wor"))
        (expect (buffer-line-count buffer) :to-equal 1)
        (expect (buffer-line buffer 0) :to-equal "hld")
        (expect buffer :to-have-point (cons 0 1)))))

  (it
    "signals an error when end precedes start"
    (let ((buffer (make-buffer :initial-content "hello")))
      (signals error (buffer-delete-region buffer 0 3 0 1))))

  (it
    "signals an error when a position is out of range even though ordering is valid"
    (let ((buffer (make-buffer :initial-content "hello")))
      (signals error (buffer-delete-region buffer 0 0 99 99))))

  (it
    "single-line delete on a non-first line of a multi-line buffer leaves other lines untouched"
    (let ((buffer (make-buffer :initial-content (format nil "one~%hello~%three"))))
      (let ((deleted (buffer-delete-region buffer 1 1 1 2)))
        (expect deleted :to-equal "e")
        (expect (buffer-line-count buffer) :to-equal 3)
        (expect (buffer-line buffer 0) :to-equal "one")
        (expect (buffer-line buffer 1) :to-equal "hllo")
        (expect (buffer-line buffer 2) :to-equal "three")
        (expect buffer :to-have-point (cons 1 1))))))
