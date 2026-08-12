;;;; src/infrastructure/terminal-renderer-cursor.lisp
(in-package #:loom)

(defgeneric loom-renderer-make-cursor (renderer &key x y visible)
  (:documentation
   "Create a terminal cursor for RENDERER with the given position and
visibility. Returns the renderer-specific cursor object.")
  (:method ((renderer loom-renderer) &key (x 0) (y 0) (visible t))
    (declare (ignore renderer))
    (cl-tty-kit:make-cursor :x x :y y :visible visible)))

(defgeneric loom-renderer-resize (renderer width height)
  (:documentation
   "Resize RENDERER's underlying screen and renderer to the given WIDTH and
HEIGHT (terminal columns and rows), as if by CL-TTY-KIT:SCREEN-RESIZE and
CL-TTY-KIT:RENDERER-RESIZE. Returns RENDERER.")
  (:method ((renderer loom-renderer) width height)
    (cl-tty-kit:renderer-resize (%loom-renderer-cl-tty-renderer renderer) width height)
    renderer))
