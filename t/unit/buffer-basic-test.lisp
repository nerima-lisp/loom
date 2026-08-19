;;;; t/unit/buffer-basic-test.lisp
(in-package #:loom/test)

(describe
  "make-buffer"
  (it
    "defaults to an empty *scratch* buffer with point/mark at 0,0"
    (let ((buffer (make-buffer)))
      (with-soft-assertions
        (expect (buffer-name buffer) :to-equal "*scratch*")
        (expect (buffer-path buffer) :to-be nil)
        (expect (buffer-line-count buffer) :to-equal 1)
        (expect (buffer-line buffer 0) :to-equal "")
        (expect buffer :to-have-point (cons 0 0))
        (expect (buffer-read-only-p buffer) :to-be-falsy)
        (expect (buffer-modified-p buffer) :to-be-falsy))))

  (it
    "takes name and path"
    (let ((buffer (make-buffer :name "foo.txt" :path #P"/tmp/foo.txt")))
      (expect (buffer-name buffer) :to-equal "foo.txt")
      (expect (buffer-path buffer) :to-equal #P"/tmp/foo.txt")))

  (it
    "splits initial-content into lines"
    (let ((buffer (make-buffer :initial-content (format nil "one~%two~%three"))))
      (expect (buffer-line-count buffer) :to-equal 3)
      (expect (buffer-line buffer 0) :to-equal "one")
      (expect (buffer-line buffer 1) :to-equal "two")
      (expect (buffer-line buffer 2) :to-equal "three")))

  (it
    "signals an error for an out-of-range buffer-line"
    (let ((buffer (make-buffer)))
      (signals error (buffer-line buffer 1))
      (signals error (buffer-line buffer -1)))))

(describe
  "buffer-text"
  (it
    "joins lines back with newlines"
    (let ((buffer (make-buffer :initial-content (format nil "one~%two~%three"))))
      (expect (buffer-text buffer) :to-equal (format nil "one~%two~%three")))))

(describe
  "buffer-set-point / buffer-point-line / buffer-point-column"
  (it
    "moves point to an in-range position"
    (let ((buffer (make-buffer :initial-content (format nil "hello~%world"))))
      (buffer-set-point buffer 1 3)
      (expect buffer :to-have-point (cons 1 3))))

  (it
    "clamps an out-of-range position"
    (let ((buffer (make-buffer :initial-content (format nil "hi~%there"))))
      (buffer-set-point buffer 99 99)
      (expect buffer :to-have-point (cons 1 5))
      (buffer-set-point buffer -5 -5)
      (expect buffer :to-have-point (cons 0 0)))))

(describe
  "buffer-mark / buffer-set-mark"
  (it
    "starts unset"
    (multiple-value-bind (line column) (buffer-mark (make-buffer))
      (expect line :to-be nil)
      (expect column :to-be nil)))

  (it
    "is set by buffer-set-mark"
    (let ((buffer (make-buffer :initial-content "hello")))
      (buffer-set-mark buffer 0 3)
      (multiple-value-bind (line column) (buffer-mark buffer)
        (expect line :to-equal 0)
        (expect column :to-equal 3)))))

(describe
  "buffer-mark-saved"
  (it
    "clears the modified state and returns the buffer"
    (let ((buffer (make-buffer :initial-content "hello")))
      (buffer-insert-string buffer "!")
      (expect (buffer-modified-p buffer) :to-be-truthy)
      (expect (buffer-mark-saved buffer) :to-be buffer)
      (expect (buffer-modified-p buffer) :to-be-falsy))))
