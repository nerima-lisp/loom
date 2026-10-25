(in-package #:loom)

(defun %loom-renderer-wrap-segment-end (string start width tab-width)
  (let ((source-index 0)
        (cell-column 0)
        (end start)
        (consumed 0))
    (dolist (grapheme (cl-tty-kit:string-graphemes string) end)
      (let* ((next-index (+ source-index (length grapheme)))
             (advance (%loom-renderer-grapheme-advance
                       grapheme cell-column tab-width)))
        (when (>= source-index start)
          (when (and (> (+ consumed advance) width) (> end start))
            (return-from %loom-renderer-wrap-segment-end end))
          (incf consumed advance)
          (setf end next-index)
          (when (>= consumed width)
            (return-from %loom-renderer-wrap-segment-end end)))
        (setf source-index next-index
              cell-column (+ cell-column advance))))))

(defun %loom-renderer-wrap-segment-ranges (string width tab-width)
  (let ((segments '())
        (start 0)
        (length (length string)))
    (loop while (< start length)
          do (let ((end (%loom-renderer-wrap-segment-end
                         string start width tab-width)))
               (push (cons start end) segments)
               (setf start end)))
    (nreverse segments)))

(defun loom-renderer-wrap-segments (renderer string width &key (tab-width 8))
  "Split STRING at grapheme boundaries into successive WIDTH-cell rows."
  (declare (ignore renderer))
  (check-type string string)
  (check-type width (integer 0 *))
  (check-type tab-width (integer 1 *))
  (if (or (equal string "") (zerop width))
      (list (cons 0 (length string)))
      (%loom-renderer-wrap-segment-ranges string width tab-width)))

(defun %loom-segment-index (segments column)
  "Return the range index holding COLUMN, clamping past-end columns."
  (or (position-if (lambda (segment)
                     (and (<= (car segment) column) (< column (cdr segment))))
                   segments)
      (max 0 (1- (length segments)))))

(defun loom-renderer-segment-cells (renderer string segment column
                                    &key (tab-width 8))
  "Return how many cells into SEGMENT character COLUMN sits."
  (declare (ignore renderer))
  (let* ((prefix-widths (%loom-renderer-cell-prefix-widths
                         string :tab-width tab-width))
         (start (car segment))
         (end (max start (min column (cdr segment)))))
    (- (aref prefix-widths end) (aref prefix-widths start))))

(defun loom-renderer-segment-column (renderer string segment cells
                                     &key (tab-width 8))
  "Return the character column CELLS cells into SEGMENT, clamped to its end."
  (declare (ignore renderer))
  (let* ((prefix-widths (%loom-renderer-cell-prefix-widths
                         string :tab-width tab-width))
         (start (car segment))
         (end (cdr segment))
         (segment-start-cell (aref prefix-widths start))
         (column start))
    (loop for index from start below end
          for segment-cells = (- (aref prefix-widths (1+ index))
                                 segment-start-cell)
          while (<= segment-cells cells)
          do (setf column (1+ index)))
    column))
