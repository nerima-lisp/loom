(in-package #:loom)

(defstruct (loom-renderer
            (:conc-name %loom-renderer-)
            (:constructor %make-loom-renderer (cl-tty-renderer))
            (:copier nil))
  "A loom renderer backed by a single CL-TTY-KIT renderer object."
  cl-tty-renderer)

(defun make-loom-renderer (width height)
  "Create and return a new loom renderer backed by a CL-TTY-KIT screen and
double-buffered diff renderer (as if by CL-TTY-KIT:MAKE-SCREEN and
CL-TTY-KIT:MAKE-RENDERER) of the given WIDTH and HEIGHT, in terminal columns
and rows respectively."
  (%make-loom-renderer (cl-tty-kit:make-renderer width height)))

(defun loom-renderer-width (renderer)
  "Return RENDERER's width in terminal columns."
  (cl-tty-kit:renderer-width (%loom-renderer-cl-tty-renderer renderer)))

(defun loom-renderer-height (renderer)
  "Return RENDERER's height in terminal rows."
  (cl-tty-kit:renderer-height (%loom-renderer-cl-tty-renderer renderer)))

(defun loom-renderer-write-string (renderer x y string &key style)
  "Write STRING at (X, Y) on RENDERER's screen, optionally using STYLE.
Returns RENDERER."
  (cl-tty-kit:screen-write-string
   (cl-tty-kit:renderer-screen (%loom-renderer-cl-tty-renderer renderer))
   x y string :style style)
  renderer)

(defun loom-renderer-draw-horizontal-line (renderer x y length)
  "Draw a horizontal line of LENGTH cells at (X, Y) on RENDERER's screen.
Returns RENDERER."
  (cl-tty-kit:screen-draw-horizontal-line
   (cl-tty-kit:renderer-screen (%loom-renderer-cl-tty-renderer renderer))
   x y length)
  renderer)

(defun loom-renderer-draw-vertical-line (renderer x y length)
  "Draw a vertical line of LENGTH cells at (X, Y) on RENDERER's screen.
Returns RENDERER."
  (cl-tty-kit:screen-draw-vertical-line
   (cl-tty-kit:renderer-screen (%loom-renderer-cl-tty-renderer renderer))
   x y length)
  renderer)

(defun loom-renderer-clear (renderer)
  "Clear RENDERER's screen. Returns RENDERER."
  (cl-tty-kit:screen-clear
   (cl-tty-kit:renderer-screen (%loom-renderer-cl-tty-renderer renderer)))
  renderer)

(defun %loom-renderer-draw-buffer-row (renderer buffer x y width line-number line-count)
  (when (< line-number line-count)
    (let* ((text (buffer-visible-line buffer line-number))
           (visible (loom-renderer-truncate-string renderer text width)))
      (loom-renderer-write-string renderer x y visible)))
  renderer)

(defun loom-renderer-draw-buffer (renderer buffer x y width height &key (start-line 0))
  "Draw BUFFER's currently visible region into RENDERER's screen, occupying
the rectangle whose top-left corner is (X, Y) and which is WIDTH columns by
HEIGHT rows, all in screen-cell coordinates. Does not itself flush anything
to a terminal -- see LOOM-RENDERER-PRESENT. Returns RENDERER."
  (let ((line-count (buffer-visible-line-count buffer)))
    (dotimes (row height)
      (%loom-renderer-draw-buffer-row renderer buffer x (+ y row) width
                                      (+ start-line row) line-count))
    renderer))

(defun loom-renderer-present (renderer &key stream cursor)
  "Flush RENDERER's pending screen diff to STREAM (an implementation-chosen
default, such as *STANDARD-OUTPUT*, is used when STREAM is not supplied) via
CL-TTY-KIT:RENDERER-RENDER, and position the terminal cursor at CURSOR (a
CL-TTY-KIT cursor object as created by CL-TTY-KIT:MAKE-CURSOR) when supplied.
Returns RENDERER."
  (let ((output-stream (or stream *standard-output*)))
    (cl-tty-kit:renderer-render (%loom-renderer-cl-tty-renderer renderer)
                                 :stream output-stream
                                 :cursor cursor)
    (finish-output output-stream))
  renderer)
