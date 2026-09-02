;;;; src/infrastructure/terminal-renderer-text-wrapping.lisp
;;;;
;;;; Infrastructure layer: wrapped screen-cell rows and vertical movement.
(in-package #:loom)

(defun %loom-renderer-wrap-segment-end (string start width)
  (let ((end start) (consumed 0) (length (length string)))
    (loop while (< end length)
          for advance = (%loom-renderer-character-advance (char string end))
          do (when (and (> (+ consumed advance) width) (> end start))
               (return))
             (incf consumed advance)
             (incf end)
             (when (>= consumed width) (return)))
    end))

(defun %loom-renderer-wrap-segment-ranges (string width)
  (let ((segments '()) (start 0) (length (length string)))
    (loop while (< start length)
          do (let ((end (%loom-renderer-wrap-segment-end string start width)))
               (push (cons start end) segments)
               (setf start end)))
    (nreverse segments)))

(defun loom-renderer-wrap-segments (renderer string width)
  "Split STRING into character ranges filling successive WIDTH-cell rows."
  (declare (ignore renderer))
  (check-type string string)
  (check-type width (integer 0 *))
  (if (or (equal string "") (zerop width))
      (list (cons 0 (length string)))
      (%loom-renderer-wrap-segment-ranges string width)))

(defun %loom-segment-index (segments column)
  "Return the range index holding COLUMN, clamping past-end columns."
  (or (position-if (lambda (segment)
                     (and (<= (car segment) column) (< column (cdr segment))))
                   segments)
      (max 0 (1- (length segments)))))

(defun loom-renderer-segment-cells (renderer string segment column)
  "Return how many cells into SEGMENT character COLUMN sits."
  (let* ((start (car segment))
         (end (max start (min column (length string)))))
    (loom-renderer-string-width renderer (subseq string start end))))

(defun loom-renderer-segment-column (renderer string segment cells)
  "Return the character column CELLS cells into SEGMENT, clamped to its end."
  (declare (ignore renderer))
  (let* ((start (car segment)) (end (cdr segment))
         (index start) (consumed 0))
    (loop while (< index end)
          for advance = (%loom-renderer-character-advance (char string index))
          do (when (> (+ consumed advance) cells) (return))
             (incf consumed advance)
             (incf index))
    index))
