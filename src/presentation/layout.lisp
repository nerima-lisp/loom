;;;; src/presentation/layout.lisp
;;;;
;;;; Presentation layer: low-level draw helpers shared by frame composition.
;;;; Window-tree rendering lives in layout-windows.lisp; this file keeps
;;;; clipping and viewport math.
(in-package #:loom)

(defun %layout-truncate-to-width (text width)
  "Return TEXT clipped to its leading WIDTH characters, or TEXT itself when it
already fits. Every draw helper in this file writes a single row into a
fixed-width region, so each of them clips through here rather than repeating
the SUBSEQ."
  (if (> (length text) width) (subseq text 0 width) text))

(defun %layout-screen-column (renderer text column)
  "Return the screen column COLUMN characters into TEXT.

A buffer position is a character count; a terminal position is a cell count,
and a full-width character occupies two cells. Every consumer that has to turn
one into the other -- cursor placement, the Ln/Col indicator -- resolves it
here, so a line cannot yield two different columns depending on who asked.
COLUMN outside TEXT clamps to its ends rather than erroring, because point may
sit past the end of a line the renderer has already clipped."
  (loom-renderer-string-width
   renderer
   (subseq text 0 (min (max column 0) (length text)))))

(defun %layout-visible-line (buffer line)
  "Return BUFFER's visible LINE, or the empty string when LINE is out of range.

Point can name a line an empty buffer does not have, and the callers here want
a measurable string rather than a bounds check of their own."
  (if (and (>= line 0) (< line (buffer-visible-line-count buffer)))
      (buffer-visible-line buffer line)
      ""))

(defun %layout-buffer-point-screen-column (renderer buffer)
  "Return the screen column of BUFFER's point within its own visible line."
  (%layout-screen-column
   renderer
   (%layout-visible-line buffer (buffer-visible-point-line buffer))
   (buffer-visible-point-column buffer)))
