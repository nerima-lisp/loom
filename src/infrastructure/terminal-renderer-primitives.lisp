;;;; src/infrastructure/terminal-renderer-primitives.lisp
;;;;
;;;; Infrastructure layer: primitive screen drawing methods for the renderer
;;;; port. The core renderer type/lifecycle stays in terminal-renderer.lisp;
;;;; this file owns direct CL-TTY-KIT screen mutation operations used by
;;;; presentation.

(in-package #:loom)
