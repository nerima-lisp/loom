;;;; src/presentation/layout-wrapping.lisp
;;;;
;;;; Presentation layer: logical lines translated into wrapped screen rows.
(in-package #:loom)

;;; ---------------------------------------------------------------------
;;; Logical lines to screen rows
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

(defun %layout-row-back-step (renderer buffer width line row)
  "Move one wrapped screen row backward from LINE and ROW.

Return the preceding position and whether the beginning of BUFFER was reached."
  (cond
    ((plusp row) (values line (1- row) nil))
    ((zerop line) (values line row t))
    (t
     (let ((previous-line (1- line)))
       (values previous-line
               (1- (%layout-segment-count renderer buffer previous-line width))
               nil)))))

(defun %layout-rows-between (renderer buffer width from-line from-row
                             to-line to-row limit)
  "Return the screen rows from (FROM-LINE, FROM-ROW) to (TO-LINE, TO-ROW).

Returns NIL once the count is known to exceed LIMIT."
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
          do (multiple-value-bind (previous-line previous-row at-start)
                 (%layout-row-back-step
                  renderer buffer width current-line current-row)
               (setf current-line previous-line
                     current-row previous-row)
               (if at-start (setf remaining 0) (decf remaining))))
    (values current-line current-row)))

(defun %layout-draw-wrapped-line (renderer text x y width mode start-row
                                  row-limit)
  "Draw TEXT's wrapped rows beginning at START-ROW, up to ROW-LIMIT rows."
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
  "Draw BUFFER wrapped into a WIDTH by HEIGHT rectangle at (X, Y)."
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
