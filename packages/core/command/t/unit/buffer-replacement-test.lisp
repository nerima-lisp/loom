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
      (expect (loom/core/buffer:buffer-point-column buffer) :to-equal 0)))
  (it
    "restores point around delete-indentation undo and redo"
    (let ((original (format nil "one~%  two~%")))
      (%with-selected-buffer-state (buffer original)
        (loom/core/buffer:buffer-set-point buffer 1 0)
        (loom/core/command::delete-indentation)
        (expect (loom/core/buffer:buffer-text buffer)
                :to-equal (format nil "one two~%"))
        (expect buffer :to-have-point (cons 0 3))
        (loom/core/buffer:buffer-undo buffer)
        (expect (loom/core/buffer:buffer-text buffer) :to-equal original)
        (expect buffer :to-have-point (cons 1 0))
        (loom/core/buffer:buffer-redo buffer)
        (expect (loom/core/buffer:buffer-text buffer)
                :to-equal (format nil "one two~%"))
        (expect buffer :to-have-point (cons 0 3))
        (loom/core/buffer:buffer-undo buffer)
        (expect (loom/core/buffer:buffer-text buffer) :to-equal original)
        (expect buffer :to-have-point (cons 1 0)))))
  (it
  "updates point in the minimal insertion and no-op paths"
  (let ((buffer (loom/core/buffer:make-buffer :initial-content "one two")))
    (loom/core/command::%replace-buffer-offset-range
     buffer 0 0 "X" :minimal-change-p t)
    (expect (loom/core/buffer:buffer-line buffer 0) :to-equal "Xone two")
    (expect buffer :to-have-point (cons 0 1))
    (loom/core/buffer:buffer-undo buffer)
    (expect (loom/core/buffer:buffer-line buffer 0) :to-equal "one two")
    (loom/core/command::%replace-buffer-offset-range
     buffer 0 3 "one" :minimal-change-p t)
    (expect (loom/core/buffer:buffer-line buffer 0) :to-equal "one two")
    (expect buffer :to-have-point (cons 0 3)))))
