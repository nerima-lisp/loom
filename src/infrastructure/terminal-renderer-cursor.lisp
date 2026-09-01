;;;; src/infrastructure/terminal-renderer-cursor.lisp
(in-package #:loom)

(defun loom-renderer-resize (renderer width height)
  "Resize RENDERER's underlying screen and renderer to the given WIDTH and
HEIGHT (terminal columns and rows), as if by CL-TTY-KIT:SCREEN-RESIZE and
CL-TTY-KIT:RENDERER-RESIZE. Returns RENDERER."
  (cl-tty-kit:renderer-resize (%loom-renderer-cl-tty-renderer renderer) width height)
  renderer)
