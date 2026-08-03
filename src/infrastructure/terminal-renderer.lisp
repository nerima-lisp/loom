;;;; src/infrastructure/terminal-renderer.lisp
;;;;
;;;; Infrastructure layer: the renderer protocol. A thin adapter wrapping a
;;;; single CL-TTY-KIT screen/renderer pair, adding the notion of drawing a
;;;; loom BUFFER's visible region into a rectangular area of the screen.
(in-package #:loom)

;;; LOOM-RENDERER wraps a single CL-TTY-KIT renderer object (itself already a
;;; back-buffer screen plus previous-frame diff state -- see
;;; CL-TTY-KIT:MAKE-RENDERER/CL-TTY-KIT:RENDERER-SCREEN). A non-default
;;; :CONC-NAME and :CONSTRUCTOR are used because MAKE-LOOM-RENDERER and
;;; LOOM-RENDERER-CL-TTY-RENDERER are themselves protocol generic functions
;;; declared below; DEFSTRUCT's default accessor/constructor names would
;;; collide with those generic function definitions.
(defstruct (loom-renderer
            (:conc-name %loom-renderer-)
            (:constructor %make-loom-renderer (cl-tty-renderer))
            (:copier nil))
  "A loom renderer: a thin wrapper around a single CL-TTY-KIT renderer object."
  cl-tty-renderer)

(defgeneric make-loom-renderer (width height)
  (:documentation
   "Create and return a new loom renderer backed by a CL-TTY-KIT screen and
double-buffered diff renderer (as if by CL-TTY-KIT:MAKE-SCREEN and
CL-TTY-KIT:MAKE-RENDERER) of the given WIDTH and HEIGHT, in terminal columns
and rows respectively.")
  (:method (width height)
    (%make-loom-renderer (cl-tty-kit:make-renderer width height))))

(defgeneric loom-renderer-cl-tty-renderer (renderer)
  (:documentation
   "Return the underlying CL-TTY-KIT renderer object (as created by
CL-TTY-KIT:MAKE-RENDERER) that RENDERER wraps.")
  (:method ((renderer loom-renderer))
    (%loom-renderer-cl-tty-renderer renderer)))

(defgeneric loom-renderer-draw-buffer (renderer buffer x y width height &key start-line)
  (:documentation
   "Draw BUFFER's currently visible region into RENDERER's screen, occupying
the rectangle whose top-left corner is (X, Y) and which is WIDTH columns by
HEIGHT rows, all in screen-cell coordinates. Does not itself flush anything
to a terminal -- see LOOM-RENDERER-PRESENT. Returns RENDERER.")
  (:method ((renderer loom-renderer) buffer x y width height &key (start-line 0))
    (let ((screen (cl-tty-kit:renderer-screen (%loom-renderer-cl-tty-renderer renderer)))
          (line-count (buffer-line-count buffer)))
      (dotimes (row height)
        (let ((line-number (+ start-line row)))
          (when (< line-number line-count)
            (let* ((text (buffer-line buffer line-number))
                   (visible (if (> (length text) width)
                                (subseq text 0 width)
                                text)))
              (cl-tty-kit:screen-write-string screen x (+ y row) visible)))))
      renderer)))

(defgeneric loom-renderer-present (renderer &key stream cursor)
  (:documentation
   "Flush RENDERER's pending screen diff to STREAM (an implementation-chosen
default, such as *STANDARD-OUTPUT*, is used when STREAM is not supplied) via
CL-TTY-KIT:RENDERER-RENDER, and position the terminal cursor at CURSOR (a
CL-TTY-KIT cursor object as created by CL-TTY-KIT:MAKE-CURSOR) when supplied.
Returns RENDERER.")
  (:method ((renderer loom-renderer) &key stream cursor)
    (cl-tty-kit:renderer-render (%loom-renderer-cl-tty-renderer renderer)
                                 :stream (or stream *standard-output*)
                                 :cursor cursor)
    renderer))

(defgeneric loom-renderer-resize (renderer width height)
  (:documentation
   "Resize RENDERER's underlying screen and renderer to the given WIDTH and
HEIGHT (terminal columns and rows), as if by CL-TTY-KIT:SCREEN-RESIZE and
CL-TTY-KIT:RENDERER-RESIZE. Returns RENDERER.")
  (:method ((renderer loom-renderer) width height)
    (cl-tty-kit:renderer-resize (%loom-renderer-cl-tty-renderer renderer) width height)
    renderer))
