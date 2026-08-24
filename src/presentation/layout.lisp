;;;; src/presentation/layout.lisp
;;;;
;;;; Presentation layer: low-level draw helpers shared by frame composition.
;;;; File-tree sidebar rendering lives in layout-file-tree.lisp; this file
;;;; keeps shared clipping, window drawing, and minibuffer rendering.
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
    (return-from %layout-rows-between nil))
  (let ((rows (- to-row from-row)))
    (loop for line from from-line below to-line
          do (incf rows (%layout-segment-count renderer buffer line width))
             (when (> rows limit)
               (return-from %layout-rows-between nil)))
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
          do (let* ((text (buffer-visible-line buffer line))
                    (segments (loom-renderer-wrap-segments
                               renderer text width)))
               (loop for index from sub-row below (length segments)
                     while (< row height)
                     do (loom/feature/syntax-highlighting:syntax-draw-highlighted-line
                         renderer text x (+ y row) width mode
                         (%layout-segment-start-column
                          renderer text (nth index segments)))
                        (incf row))
               (setf sub-row 0)
               (incf line)))
    renderer))

(defun %layout-draw-window-buffer (renderer window x-offset)
  "Draw WINDOW's buffer in whichever line-display mode that buffer selects."
  (let* ((buffer (loom/feature/window:window-buffer window))
         (x (+ x-offset (loom/feature/window:window-x window)))
         (y (loom/feature/window:window-y window))
         (width (loom/feature/window:window-width window))
         (height (loom/feature/window:window-height window)))
    (if (loom/feature/mode:buffer-truncate-lines-p buffer)
        (loom/feature/syntax-highlighting:syntax-draw-buffer
         renderer buffer x y width height
         :start-line (loom/feature/window:window-scroll-line window)
         :start-column (loom/feature/window:window-scroll-column window))
        (%layout-draw-wrapped-buffer
         renderer buffer x y width height
         (loom/feature/window:window-scroll-line window)
         (loom/feature/window:window-scroll-sub-row window)))))

;;; ---------------------------------------------------------------------
;;; Incremental-search highlighting
;;; ---------------------------------------------------------------------

(defparameter +layout-isearch-match-style+ '((:bg 3) (:fg 0))
  "Style for a search match that is not the one point sits on.")

(defparameter +layout-isearch-current-style+ '((:bg 6) (:fg 0))
  "Style for the match point currently sits on, so it reads apart from the rest.")

(defun %layout-draw-line-run (renderer window x-offset line start end style)
  "Redraw characters [START, END) of WINDOW's buffer LINE in STYLE.

The run is placed with the same geometry the buffer text was drawn with, which
means splitting it per wrapped segment when the window wraps and shifting it by
the scroll column when it truncates. A run scrolled or wrapped off the window
draws nothing rather than clipping to the wrong row."
  (let* ((buffer (loom/feature/window:window-buffer window))
         (text (%layout-visible-line buffer line))
         (width (loom/feature/window:window-width window))
         (height (loom/feature/window:window-height window))
         (y (loom/feature/window:window-y window))
         (x (+ x-offset (loom/feature/window:window-x window)))
         (start (max 0 (min start (length text))))
         (end (max start (min end (length text)))))
    (when (and (plusp width) (plusp height) (> end start))
      (if (loom/feature/mode:buffer-truncate-lines-p buffer)
          (let ((row (- line (loom/feature/window:window-scroll-line window)))
                (column (- (%layout-screen-column renderer text start)
                           (loom/feature/window:window-scroll-column window))))
            (when (and (<= 0 row) (< row height) (<= 0 column) (< column width))
              (loom-renderer-write-string
               renderer (+ x column) (+ y row)
               (loom-renderer-truncate-string
                renderer (subseq text start end) (- width column))
               :style style)))
          (dolist (segment (loom-renderer-wrap-segments renderer text width))
            (let ((from (max start (car segment)))
                  (to (min end (cdr segment))))
              (when (> to from)
                (let ((row (%layout-rows-between
                            renderer buffer width
                            (loom/feature/window:window-scroll-line window)
                            (loom/feature/window:window-scroll-sub-row window)
                            line
                            (%loom-segment-index
                             (loom-renderer-wrap-segments renderer text width)
                             from)
                            (1- height)))
                      (column (loom-renderer-segment-cells
                               renderer text segment from)))
                  (when row
                    (loom-renderer-write-string
                     renderer (+ x column) (+ y row)
                     (loom-renderer-truncate-string
                      renderer (subseq text from to) (- width column))
                     :style style))))))))))

(defun %layout-draw-span (renderer window x-offset span style)
  "Redraw the buffer text SPAN covers in STYLE, one logical line at a time."
  (let* ((buffer (loom/feature/window:window-buffer window))
         (start (buffer-visible-offset-position buffer
                                                (buffer-span-start span)))
         (end (buffer-visible-offset-position buffer (buffer-span-end span))))
    (when (and start end)
      (let ((first-line (buffer-position-line start))
            (last-line (buffer-position-line end)))
        (loop for line from first-line to last-line
              do (%layout-draw-line-run
                  renderer window x-offset line
                  (if (= line first-line) (buffer-position-column start) 0)
                  (if (= line last-line)
                      (buffer-position-column end)
                      (length (%layout-visible-line buffer line)))
                  style))))))

(defun %layout-draw-isearch (renderer window x-offset)
  "Highlight the active incremental search's matches inside WINDOW.

Only the window's own buffer is highlighted: a session belongs to the buffer it
started in, and painting its offsets onto a different buffer would mark text
that never matched."
  (let ((session (and *editor-state* (editor-state-isearch *editor-state*))))
    (when (and session
               (eq (loom/feature/search:isearch-session-buffer session)
                   (loom/feature/window:window-buffer window)))
      (let ((current (loom/feature/search:isearch-session-match session)))
        (dolist (span (loom/feature/search:isearch-session-matches session))
          (%layout-draw-span renderer window x-offset span
                             (if (and current
                                      (= (buffer-span-start span)
                                         (buffer-span-start current)))
                                 +layout-isearch-current-style+
                                 +layout-isearch-match-style+)))))))

;;; ---------------------------------------------------------------------
;;; Matching parenthesis
;;; ---------------------------------------------------------------------

(defparameter +layout-matching-paren-style+ '(:bold (:bg 5) (:fg 0))
  "Style marking the parenthesis at point and the one it pairs with.")

(defun %layout-draw-matching-paren (renderer window x-offset)
  "Mark the parenthesis point is adjacent to, together with its partner.

Nothing is drawn when point is next to no parenthesis, and nothing when the
text does not balance: pointing at a parenthesis that is not actually the
partner is worse than saying nothing, because it reads as confirmation."
  (let* ((buffer (loom/feature/window:window-buffer window))
         (start (buffer-narrow-start-offset buffer))
         (text (buffer-visible-text buffer))
         (offset (max 0 (min (length text)
                             (- (buffer-point-offset buffer) start)))))
    (multiple-value-bind (paren match) (%matching-paren-offset text offset)
      (when (and paren match)
        (dolist (local (list paren match))
          (let ((position (buffer-visible-offset-position
                           buffer (+ start local))))
            (when position
              (%layout-draw-line-run
               renderer window x-offset
               (buffer-position-line position)
               (buffer-position-column position)
               (1+ (buffer-position-column position))
               +layout-matching-paren-style+))))))))

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

(defun %layout-draw-windows (renderer window-tree x-offset)
  "Draw every leaf window in WINDOW-TREE (already laid out by
WINDOW-TREE-RESIZE against the window area's own width/height) via
%LAYOUT-DRAW-BUFFER, each leaf's rect offset horizontally by X-OFFSET
columns -- the width consumed by a visible file-tree sidebar, so a leaf's own
WINDOW-X/WINDOW-Y (relative to the window tree's own origin) land in the
right place on the shared screen. When a split produced more than one leaf, a
 minimal 1-cell separator line is drawn along the shared edge between any two
horizontally- or vertically-adjacent leaves, so a user can tell the panes
apart. Returns RENDERER."
  (let ((leaves (loom/feature/window:window-tree-windows window-tree)))
    (dolist (leaf leaves)
      (%layout-draw-window-buffer renderer leaf x-offset)
      (%layout-draw-matching-paren renderer leaf x-offset)
      (%layout-draw-isearch renderer leaf x-offset)
      (%layout-draw-completion renderer leaf x-offset))
    (dolist (leaf leaves)
      ;; A leaf whose X is not 0 (relative to the window-tree's own origin)
      ;; has a neighbor immediately to its left from a :VERTICAL split; draw
      ;; a vertical rule just left of this leaf's own left edge.
      (when (and (plusp (loom/feature/window:window-x leaf))
                 (plusp (loom/feature/window:window-height leaf)))
        (loom-renderer-draw-vertical-line
         renderer (1- (+ x-offset (loom/feature/window:window-x leaf)))
         (loom/feature/window:window-y leaf)
         (loom/feature/window:window-height leaf)))
      ;; Likewise, a leaf whose Y is not 0 has a neighbor immediately above it
      ;; from a :HORIZONTAL split; draw a horizontal rule just above it.
      (when (and (plusp (loom/feature/window:window-y leaf))
                 (plusp (loom/feature/window:window-width leaf)))
        (loom-renderer-draw-horizontal-line
         renderer (+ x-offset (loom/feature/window:window-x leaf))
         (1- (loom/feature/window:window-y leaf))
         (loom/feature/window:window-width leaf))))
  renderer))
