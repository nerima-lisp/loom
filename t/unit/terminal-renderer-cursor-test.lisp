;;;; t/unit/terminal-renderer-cursor-test.lisp

(in-package #:loom/test)

(describe
  "loom-renderer-resize"
  (it
    "resizes the underlying cl-tty-kit renderer and returns the renderer"
    (let ((renderer (make-loom-renderer 4 4)))
      (expect (loom-renderer-resize renderer 8 2) :to-be renderer)
      (let ((cl-tty-renderer (loom::%loom-renderer-cl-tty-renderer renderer)))
        (expect (cl-tty-kit:renderer-width cl-tty-renderer) :to-equal 8)
        (expect (cl-tty-kit:renderer-height cl-tty-renderer) :to-equal 2)))))

(describe
  "%layout-screen-column"
  (it-each
      (("" 0 0)
       ("hello" 0 0)
       ("hello" 3 3)
       ("hello" 5 5)
       ("hello" 9 5)
       ("hello" -1 0)
       ("あいう" 0 0)
       ("あいう" 1 2)
       ("あいう" 3 6)
       ("aあb" 1 1)
       ("aあb" 2 3)
       ("aあb" 3 4))
      "measures ~S at character ~D as screen column ~D"
      (text column expected)
    (expect (loom::%layout-screen-column (make-loom-renderer 40 6) text column)
            :to-equal expected)))

(describe
  "loom-renderer-make-cursor"
  (it
    "creates a visible cursor at the origin by default"
    (let ((cursor (loom-renderer-make-cursor (make-loom-renderer 10 4))))
      (expect (cl-tty-kit:cursor-x cursor) :to-equal 0)
      (expect (cl-tty-kit:cursor-y cursor) :to-equal 0)
      (expect (cl-tty-kit:cursor-visible-p cursor) :to-be-truthy)))
  (it
    "preserves explicit position and visibility"
    (let ((cursor (loom-renderer-make-cursor (make-loom-renderer 10 4)
                                             :x 3 :y 2 :visible nil)))
      (expect (cl-tty-kit:cursor-x cursor) :to-equal 3)
      (expect (cl-tty-kit:cursor-y cursor) :to-equal 2)
      (expect (cl-tty-kit:cursor-visible-p cursor) :to-be-falsy))))
