;;;; src/infrastructure/terminal-renderer-primitives.lisp
;;;;
;;;; Infrastructure layer: primitive screen drawing methods for the renderer
;;;; port. The core renderer type/lifecycle stays in terminal-renderer.lisp;
;;;; this file owns direct CL-TTY-KIT screen mutation operations used by
;;;; presentation.

(in-package #:loom)

(defmethod loom-renderer-write-string ((renderer loom-renderer) x y string &key style)
  (cl-tty-kit:screen-write-string
   (cl-tty-kit:renderer-screen (%loom-renderer-cl-tty-renderer renderer))
   x y string :style style)
  renderer)

(defmethod loom-renderer-draw-horizontal-line ((renderer loom-renderer) x y length)
  (cl-tty-kit:screen-draw-horizontal-line
   (cl-tty-kit:renderer-screen (%loom-renderer-cl-tty-renderer renderer))
   x y length)
  renderer)

(defmethod loom-renderer-draw-vertical-line ((renderer loom-renderer) x y length)
  (cl-tty-kit:screen-draw-vertical-line
   (cl-tty-kit:renderer-screen (%loom-renderer-cl-tty-renderer renderer))
   x y length)
  renderer)

(defmethod loom-renderer-clear ((renderer loom-renderer))
  (cl-tty-kit:screen-clear
   (cl-tty-kit:renderer-screen (%loom-renderer-cl-tty-renderer renderer)))
  renderer)
