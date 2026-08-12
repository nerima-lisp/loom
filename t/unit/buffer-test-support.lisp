;;;; t/unit/buffer-test-support.lisp
(in-package #:loom/test)

(defmatcher :to-have-point (buffer expected)
  "buffer's point to equal the given (line . column)"
  (let ((actual-point (cons (buffer-point-line buffer) (buffer-point-column buffer)))
        (expected-point (first expected)))
    (values (equal actual-point expected-point) actual-point expected-point)))
