(in-package #:loom/test)

(describe
  "buffer replacement"
  (it
    "replaces and undoes a word through the nonminimal replacement branch"
    (let ((buffer (loom/core/buffer:make-buffer :initial-content "one two")))
      (loom/core/command::%replace-buffer-offset-range buffer 0 3 "ONE")
      (expect (loom/core/buffer:buffer-line buffer 0) :to-equal "ONE two")
      (expect (loom/core/buffer:buffer-point-column buffer) :to-equal 3)
      (loom/core/buffer:buffer-undo buffer)
      (expect (loom/core/buffer:buffer-line buffer 0) :to-equal "one two")
      (expect (loom/core/buffer:buffer-point-column buffer) :to-equal 0))))
