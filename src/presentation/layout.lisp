(in-package #:loom)

(defun %layout-truncate-to-width (text width)
  "Return the longest prefix of TEXT that fits WIDTH screen cells."
  (loom-renderer-truncate-string nil text width))

(defun %layout-screen-column (renderer text column &optional (tab-width 8))
  "Return the screen column COLUMN characters into TEXT.

A buffer position is a character count; a terminal position is a cell count,
and a full-width character occupies two cells. Every consumer that has to turn
one into the other -- cursor placement, the Ln/Col indicator -- resolves it
here, so a line cannot yield two different columns depending on who asked.
COLUMN outside TEXT clamps to its ends rather than erroring, because point may
sit past the end of a line the renderer has already clipped."
  (loom-renderer-string-width
   renderer
   (subseq text 0 (min (max column 0) (length text)))
   :tab-width tab-width))

(defun %layout-visible-line (buffer line)
  "Return BUFFER's visible LINE, or the empty string when LINE is out of range.

Point can name a line an empty buffer does not have, and the callers here want
a measurable string rather than a bounds check of their own."
  (if (and (>= line 0) (< line (buffer-visible-line-count buffer)))
      (buffer-visible-line buffer line)
      ""))

(defun %layout-mode-tab-width (mode)
  (max 1 (loom/feature/mode:major-mode-tab-width mode)))

(defun %layout-buffer-line-display (buffer line)
  "Return BUFFER's line with tabs expanded and source-to-display indexes."
  (%loom-renderer-expand-tabs
   (%layout-visible-line buffer line)
   :tab-width (%layout-mode-tab-width (buffer-major-mode buffer))))

(defun %layout-buffer-display-column (buffer line source-column)
  (multiple-value-bind (text mapping)
      (%layout-buffer-line-display buffer line)
    (declare (ignore text))
    (aref mapping
          (min (max source-column 0)
               (1- (length mapping))))))

(defun %layout-buffer-point-screen-column (renderer buffer)
  "Return the screen column of BUFFER's point within its own visible line."
  (%layout-screen-column
   renderer
   (%layout-visible-line buffer (buffer-visible-point-line buffer))
   (buffer-visible-point-column buffer)
   (%layout-mode-tab-width (buffer-major-mode buffer))))

(defun %layout-window-content-height (window)
  "Return the rows available for WINDOW's buffer above its mode line."
  (max 0 (1- (loom/core/window-tree:window-height window))))
(defun %layout-window-gutter-width (buffer width)
  "Return the reserved line-number gutter width for BUFFER in WIDTH cells."
  (let* ((line-count (max 1 (buffer-visible-line-count buffer)))
         (number-width (length (write-to-string line-count)))
         (gutter-width (1+ number-width)))
    (if (or (member (buffer-major-mode buffer)
                    '(:fundamental :markdown :org :text)
                    :test #'eq)
            (< width (1+ gutter-width)))
        0
        gutter-width)))
