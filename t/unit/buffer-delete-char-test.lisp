;;;; t/unit/buffer-delete-char-test.lisp
(in-package #:loom/test)

(describe
  "buffer-delete-char"
  (it
    "backward deletes the character before point and moves point back"
    (let ((buffer (make-buffer :initial-content "hello")))
      (buffer-set-point buffer 0 5)
      (buffer-delete-char buffer :backward t)
      (expect (buffer-line buffer 0) :to-equal "hell")
      (expect (buffer-point-column buffer) :to-equal 4)))

  (it
    "backward is a no-op at the start of the buffer"
    (let ((buffer (make-buffer :initial-content "hello")))
      (buffer-delete-char buffer :backward t)
      (expect (buffer-line buffer 0) :to-equal "hello")
      (expect (buffer-modified-p buffer) :to-be-falsy)))

  (it
    "backward at column 0 joins with the previous line"
    (let ((buffer (make-buffer :initial-content (format nil "hello~%world"))))
      (buffer-set-point buffer 1 0)
      (buffer-delete-char buffer :backward t)
      (expect (buffer-line-count buffer) :to-equal 1)
      (expect (buffer-line buffer 0) :to-equal "helloworld")
      (expect buffer :to-have-point (cons 0 5))))

  (it
    "forward deletes the character at point and leaves point where it is"
    (let ((buffer (make-buffer :initial-content "hello")))
      (buffer-set-point buffer 0 0)
      (buffer-delete-char buffer)
      (expect (buffer-line buffer 0) :to-equal "ello")
      (expect (buffer-point-column buffer) :to-equal 0)))

  (it
    "forward at the end of a non-last line joins with the next line"
    (let ((buffer (make-buffer :initial-content (format nil "one~%two"))))
      (buffer-set-point buffer 0 3)
      (buffer-delete-char buffer)
      (expect (buffer-text buffer) :to-equal "onetwo")
      (expect buffer :to-have-point (cons 0 3))))

  (it
    "forward is a no-op at the end of the buffer"
    (let ((buffer (make-buffer :initial-content "hello")))
      (buffer-set-point buffer 0 5)
      (buffer-delete-char buffer)
      (expect (buffer-line buffer 0) :to-equal "hello")
      (expect (buffer-modified-p buffer) :to-be-falsy))))
