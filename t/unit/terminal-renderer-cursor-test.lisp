;;;; t/unit/terminal-renderer-cursor-test.lisp

(in-package #:loom/test)

(describe
  "loom-renderer-resize"
  (it
    "resizes the underlying cl-tty-kit renderer and returns the renderer"
    (let* ((renderer (make-loom-renderer 4 4)))
      (expect (loom-renderer-resize renderer 8 2) :to-be renderer)
      (let ((cl-tty-renderer (loom::%loom-renderer-cl-tty-renderer renderer)))
        (expect (cl-tty-kit:renderer-width cl-tty-renderer) :to-equal 8)
        (expect (cl-tty-kit:renderer-height cl-tty-renderer) :to-equal 2)))))

(describe
  "loom-renderer-make-cursor"
  (it
    "creates a visible cursor at the origin by default"
    (let ((cursor (loom-renderer-make-cursor (make-loom-renderer 10 4))))
      (expect (cl-tty-kit:cursor-x cursor) :to-equal 0)
      (expect (cl-tty-kit:cursor-y cursor) :to-equal 0)
      (expect (cl-tty-kit:cursor-visible-p cursor) :to-be-truthy))))
