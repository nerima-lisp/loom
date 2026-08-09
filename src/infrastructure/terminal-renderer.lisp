;;;; src/infrastructure/terminal-renderer.lisp
;;;;
;;;; Infrastructure layer: the renderer port. It owns a single CL-TTY-KIT
;;;; screen/renderer pair and exposes only the drawing capabilities that
;;;; presentation needs for a loom BUFFER's visible region.
(in-package #:loom)

;;; LOOM-RENDERER wraps a single CL-TTY-KIT renderer object (itself already a
;;; back-buffer screen plus previous-frame diff state -- see
;;; CL-TTY-KIT:MAKE-RENDERER/CL-TTY-KIT:RENDERER-SCREEN). The concrete
;;; renderer accessor remains private to infrastructure; presentation consumes
;;; only the LOOM-RENDERER-* protocol below.
(defstruct (loom-renderer
            (:conc-name %loom-renderer-)
            (:constructor %make-loom-renderer (cl-tty-renderer))
            (:copier nil))
  "A loom renderer backed by a single CL-TTY-KIT renderer object."
  cl-tty-renderer)

(defgeneric make-loom-renderer (width height)
  (:documentation
   "Create and return a new loom renderer backed by a CL-TTY-KIT screen and
double-buffered diff renderer (as if by CL-TTY-KIT:MAKE-SCREEN and
CL-TTY-KIT:MAKE-RENDERER) of the given WIDTH and HEIGHT, in terminal columns
and rows respectively.")
  (:method (width height)
    (%make-loom-renderer (cl-tty-kit:make-renderer width height))))

(defgeneric loom-renderer-width (renderer)
  (:documentation
   "Return RENDERER's width in terminal columns.")
  (:method ((renderer loom-renderer))
    (cl-tty-kit:renderer-width (%loom-renderer-cl-tty-renderer renderer))))

(defgeneric loom-renderer-height (renderer)
  (:documentation
   "Return RENDERER's height in terminal rows.")
  (:method ((renderer loom-renderer))
    (cl-tty-kit:renderer-height (%loom-renderer-cl-tty-renderer renderer))))

(defgeneric loom-renderer-write-string (renderer x y string &key style)
  (:documentation
   "Write STRING at (X, Y) on RENDERER's screen, optionally using STYLE.
Returns RENDERER.")
  (:method ((renderer loom-renderer) x y string &key style)
    (cl-tty-kit:screen-write-string
     (cl-tty-kit:renderer-screen (%loom-renderer-cl-tty-renderer renderer))
     x y string :style style)
    renderer))

(defun %loom-renderer-character-advance (character)
  (if (= (cl-tty-kit:char-width character) 2)
      2
      1))

(defgeneric loom-renderer-string-width (renderer string)
  (:documentation
   "Return STRING's width in the screen-cell coordinates of RENDERER.")
  (:method ((renderer loom-renderer) string)
    (declare (ignore renderer))
    (check-type string string)
    (loop for character across string
          sum (%loom-renderer-character-advance character))))

(defgeneric loom-renderer-truncate-string (renderer string width)
  (:documentation
   "Return the longest prefix of STRING that fits WIDTH screen cells.")
  (:method ((renderer loom-renderer) string width)
    (check-type string string)
    (check-type width (integer 0 *))
    (let ((position 0)
          (consumed 0)
          (length (length string)))
      (loop while (< position length)
            for advance = (%loom-renderer-character-advance
                           (char string position))
            do (if (> (+ consumed advance) width)
                   (return)
                   (progn
                     (incf consumed advance)
                     (incf position))))
      (if (= position length)
          string
          (subseq string 0 position)))))

(defgeneric loom-renderer-draw-horizontal-line (renderer x y length)
  (:documentation
   "Draw a horizontal line of LENGTH cells at (X, Y) on RENDERER's screen.
Returns RENDERER.")
  (:method ((renderer loom-renderer) x y length)
    (cl-tty-kit:screen-draw-horizontal-line
     (cl-tty-kit:renderer-screen (%loom-renderer-cl-tty-renderer renderer))
     x y length)
    renderer))

(defgeneric loom-renderer-draw-vertical-line (renderer x y length)
  (:documentation
   "Draw a vertical line of LENGTH cells at (X, Y) on RENDERER's screen.
Returns RENDERER.")
  (:method ((renderer loom-renderer) x y length)
    (cl-tty-kit:screen-draw-vertical-line
     (cl-tty-kit:renderer-screen (%loom-renderer-cl-tty-renderer renderer))
     x y length)
    renderer))

(defgeneric loom-renderer-clear (renderer)
  (:documentation
   "Clear RENDERER's screen. Returns RENDERER.")
  (:method ((renderer loom-renderer))
    (cl-tty-kit:screen-clear
     (cl-tty-kit:renderer-screen (%loom-renderer-cl-tty-renderer renderer)))
    renderer))

(defgeneric loom-renderer-make-cursor (renderer &key x y visible)
  (:documentation
   "Create a terminal cursor for RENDERER with the given position and
visibility. Returns the renderer-specific cursor object.")
  (:method ((renderer loom-renderer) &key (x 0) (y 0) (visible t))
    (declare (ignore renderer))
    (cl-tty-kit:make-cursor :x x :y y :visible visible)))

(defgeneric loom-renderer-draw-buffer (renderer buffer x y width height &key start-line)
  (:documentation
   "Draw BUFFER's currently visible region into RENDERER's screen, occupying
the rectangle whose top-left corner is (X, Y) and which is WIDTH columns by
HEIGHT rows, all in screen-cell coordinates. Does not itself flush anything
to a terminal -- see LOOM-RENDERER-PRESENT. Returns RENDERER.")
  (:method ((renderer loom-renderer) buffer x y width height &key (start-line 0))
    (let ((line-count (buffer-line-count buffer)))
      (dotimes (row height)
        (let ((line-number (+ start-line row)))
          (when (< line-number line-count)
            (let* ((text (buffer-line buffer line-number))
                   (visible (loom-renderer-truncate-string
                             renderer text width)))
              (loom-renderer-write-string renderer x (+ y row) visible)))))
      renderer)))

(defgeneric loom-renderer-present (renderer &key stream cursor)
  (:documentation
   "Flush RENDERER's pending screen diff to STREAM (an implementation-chosen
default, such as *STANDARD-OUTPUT*, is used when STREAM is not supplied) via
CL-TTY-KIT:RENDERER-RENDER, and position the terminal cursor at CURSOR (a
CL-TTY-KIT cursor object as created by CL-TTY-KIT:MAKE-CURSOR) when supplied.
Returns RENDERER.")
  (:method ((renderer loom-renderer) &key stream cursor)
    (let ((output-stream (or stream *standard-output*)))
      (cl-tty-kit:renderer-render (%loom-renderer-cl-tty-renderer renderer)
                                   :stream output-stream
                                   :cursor cursor)
      ;; Interactive terminal frames must be visible before the next input
      ;; event.  CL-TTY-KIT writes the escape sequence diff but does not own
      ;; the stream's buffering policy.
      (finish-output output-stream))
    renderer))

(defgeneric loom-renderer-resize (renderer width height)
  (:documentation
   "Resize RENDERER's underlying screen and renderer to the given WIDTH and
HEIGHT (terminal columns and rows), as if by CL-TTY-KIT:SCREEN-RESIZE and
CL-TTY-KIT:RENDERER-RESIZE. Returns RENDERER.")
  (:method ((renderer loom-renderer) width height)
    (cl-tty-kit:renderer-resize (%loom-renderer-cl-tty-renderer renderer) width height)
    renderer))
