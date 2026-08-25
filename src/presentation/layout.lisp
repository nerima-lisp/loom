;;;; src/presentation/layout.lisp
;;;;
;;;; Presentation layer: low-level draw helpers shared by frame composition.
;;;; Window-tree rendering lives in layout-windows.lisp; this file keeps
;;;; clipping, viewport math, and wrapped-buffer rendering.
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

;;; ---------------------------------------------------------------------
;;; Window-tree area
;;; ---------------------------------------------------------------------

;;; ---------------------------------------------------------------------
;;; Logical lines to screen rows
;;;
;;; A truncating window keeps one screen row per logical line, so the two
;;; numbering systems coincide and only the horizontal offset differs. A
;;; wrapping window does not, and every helper below exists to convert between
;;; them without ever walking the whole buffer: each one is bounded by the rows
;;; on screen or by the distance actually travelled (NFR-001).
;;; ---------------------------------------------------------------------

(defun %layout-line-segments (renderer buffer line width)
  "Return the wrapped character ranges of BUFFER's visible LINE in WIDTH cells."
  (loom-renderer-wrap-segments renderer
                               (%layout-visible-line buffer line)
                               width))

(defun %layout-segment-count (renderer buffer line width)
  (length (%layout-line-segments renderer buffer line width)))

(defun %layout-segment-start-column (renderer text segment)
  "Return the screen column TEXT's SEGMENT starts at within its logical line."
  (loom-renderer-string-width renderer (subseq text 0 (car segment))))

(defun %layout-rows-between (renderer buffer width from-line from-row
                             to-line to-row limit)
  "Return the screen rows from (FROM-LINE, FROM-ROW) to (TO-LINE, TO-ROW).

Returns NIL once the count is known to exceed LIMIT, so a point far below the
viewport costs the height of the window rather than the distance to it."
  (when (or (> from-line to-line)
            (and (= from-line to-line) (> from-row to-row)))
    (return-from %layout-rows-between))
  (let ((rows (- to-row from-row)))
    (loop for line from from-line below to-line
          do (incf rows (%layout-segment-count renderer buffer line width))
             (when (> rows limit)
               (return-from %layout-rows-between)))
    (and (<= rows limit) rows)))

(defun %layout-row-back (renderer buffer width line row count)
  "Return the (LINE, ROW) position COUNT screen rows above (LINE, ROW)."
  (let ((current-line line)
        (current-row row)
        (remaining count))
    (loop while (plusp remaining)
          do (cond
               ((plusp current-row)
                (decf current-row)
                (decf remaining))
               ((zerop current-line)
                (setf remaining 0))
               (t
                (decf current-line)
                (setf current-row
                      (1- (%layout-segment-count
                           renderer buffer current-line width)))
                (decf remaining))))
    (values current-line current-row)))

(defun %layout-draw-wrapped-line (renderer text x y width mode start-row
                                  row-limit)
  "Draw TEXT's wrapped rows beginning at START-ROW, up to ROW-LIMIT rows.

Return the number of screen rows drawn.  Keeping this operation independent
of BUFFER makes the line renderer an isolated translation from wrapped segments
to draw calls; the buffer renderer only has to advance its viewport cursor."
  (let ((segments (loom-renderer-wrap-segments renderer text width))
        (drawn 0))
    (loop for index from start-row below (length segments)
          while (< drawn row-limit)
          do (loom/feature/syntax-highlighting:syntax-draw-highlighted-line
              renderer text x (+ y drawn) width mode
              (%layout-segment-start-column renderer text (nth index segments)))
             (incf drawn))
    drawn))

(defun %layout-draw-wrapped-buffer (renderer buffer x y width height
                                    scroll-line scroll-sub-row)
  "Draw BUFFER wrapped into a WIDTH by HEIGHT rectangle at (X, Y).

Each wrapped row is the same logical line drawn at the screen column its
segment begins on, which is exactly what the truncating path already does for a
horizontal scroll offset -- so wrapping needs no second clipping rule."
  (let ((mode (buffer-major-mode buffer))
        (line-count (buffer-visible-line-count buffer))
        (row 0)
        (line scroll-line)
        (sub-row scroll-sub-row))
    (loop while (and (< row height) (< line line-count))
          do (incf row
                   (%layout-draw-wrapped-line
                    renderer (buffer-visible-line buffer line) x (+ y row)
                    width mode sub-row (- height row)))
             (setf sub-row 0)
             (incf line))
    renderer))
;;; ---------------------------------------------------------------------
;;; Completion popup
;;; ---------------------------------------------------------------------

(defparameter +layout-completion-rows+ 8
  "Most candidate rows drawn at once, so a long list cannot cover the buffer.")

(defparameter +layout-completion-width+ 40
  "Widest the popup grows, in screen cells.")

(defparameter +layout-completion-style+ '((:bg 4) (:fg 7))
  "Style for a candidate the user has not selected.")

(defparameter +layout-completion-selected-style+ '(:bold (:bg 6) (:fg 0))
  "Style for the highlighted candidate.")

(defun %layout-completion-rows (renderer completion)
  "Return the labels to draw and the index of the selected one among them.

A list longer than the popup is scrolled so the selection stays visible, which
is why the window into it starts from the selection rather than from zero."
  (let* ((items (editor-completion-items completion))
         (count (length items))
         (visible (min count +layout-completion-rows+))
         (index (editor-completion-index completion))
         (first (max 0 (min (- index (floor visible 2)) (- count visible))))
         (labels (loop for offset below visible
                       collect (editor-completion-item-label
                                (nth (+ first offset) items)))))
    (values (mapcar (lambda (label)
                      (loom-renderer-truncate-string
                       renderer label +layout-completion-width+))
                    labels)
            (- index first))))

(defun %layout-completion-origin (renderer window completion height)
  "Return the (COLUMN ROW) the popup's first row occupies, or NIL when the
anchor is off screen.

The popup sits under its anchor unless it would run off the bottom, in which
case it sits above -- a list drawn past the last row would simply not appear."
  (multiple-value-bind (column row)
      (%layout-buffer-cell renderer window
                           (loom/feature/window:window-buffer window)
                           (editor-completion-line completion)
                           (editor-completion-column completion))
    (let* ((items (min (length (editor-completion-items completion))
                       +layout-completion-rows+))
           (below (1+ row))
           (above (- row items)))
      (when (and (<= 0 row) (< row height) (<= 0 column))
        (cond ((<= (+ below items) height) (values column below))
              ((<= 0 above) (values column above))
              (t nil))))))

(defun %layout-draw-completion (renderer window x-offset)
  "Draw the active completion popup when it belongs to WINDOW's buffer."
  (let ((completion (and *editor-state*
                         (editor-state-completion *editor-state*))))
    (when (and completion
               (eq (editor-completion-buffer completion)
                   (loom/feature/window:window-buffer window))
               (editor-completion-items completion))
      (let ((width (loom/feature/window:window-width window))
            (height (loom/feature/window:window-height window)))
        (when (and (plusp width) (plusp height))
          (multiple-value-bind (rows selected)
              (%layout-completion-rows renderer completion)
            (multiple-value-bind (column row)
                (%layout-completion-origin renderer window completion height)
              (when column
                (let* ((x (+ x-offset (loom/feature/window:window-x window)
                             (min column (1- width))))
                       (y (loom/feature/window:window-y window))
                       (cells (min (- width (min column (1- width)))
                                   (loop for text in rows
                                         maximize (loom-renderer-string-width
                                                   renderer text)))))
                  (loop for text in rows
                        for offset from 0
                        do (loom-renderer-write-string
                            renderer x (+ y row offset)
                            (cl-tty-kit:pad-string
                             (loom-renderer-truncate-string
                              renderer text cells)
                             cells)
                            :style (if (= offset selected)
                                       +layout-completion-selected-style+
                                       +layout-completion-style+))))))))))))
