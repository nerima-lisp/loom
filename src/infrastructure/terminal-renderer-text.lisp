;;;; src/infrastructure/terminal-renderer-text.lisp
;;;;
;;;; Infrastructure layer: screen-cell measurement helpers for the renderer
;;;; protocol. The drawing port stays in terminal-renderer.lisp; this file
;;;; owns only text width/truncation behavior shared by presentation code and
;;;; buffer drawing.
(in-package #:loom)

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

(defgeneric loom-renderer-wrap-segments (renderer string width)
  (:documentation
   "Split STRING into the character ranges filling successive WIDTH-cell rows.

Returns a list of (START . END) character indices with at least one element, so
an empty line still occupies a row. No range ends inside a full-width
character. A WIDTH of 1 still takes one full-width character per range rather
than none: a range that consumed nothing would not terminate the walk, and a
half-drawn character is what the caller clips away anyway. WIDTH 0 yields the
whole string as one range, which is what a zero-width window draws: nothing.")
  (:method ((renderer loom-renderer) string width)
    (check-type string string)
    (check-type width (integer 0 *))
    (let ((length (length string)))
      (if (or (zerop length) (zerop width))
          (list (cons 0 length))
          (let ((segments '())
                (start 0))
            (loop while (< start length)
                  do (let ((end start)
                           (consumed 0))
                       (loop while (< end length)
                             for advance = (%loom-renderer-character-advance
                                            (char string end))
                             do (when (and (> (+ consumed advance) width)
                                           (> end start))
                                  (return))
                                (incf consumed advance)
                                (incf end)
                                (when (>= consumed width)
                                  (return)))
                       (push (cons start end) segments)
                       (setf start end)))
            (nreverse segments))))))

(defun %loom-segment-index (segments column)
  "Return the index of the LOOM-RENDERER-WRAP-SEGMENTS range holding COLUMN.

A column at or past the end of the last range belongs to that range: point may
legitimately sit one character past the end of a line."
  (or (position-if (lambda (segment)
                     (and (<= (car segment) column) (< column (cdr segment))))
                   segments)
      (max 0 (1- (length segments)))))

(defgeneric loom-renderer-segment-cells (renderer string segment column)
  (:documentation
   "Return how many cells into SEGMENT of STRING the character COLUMN sits.

This is the goal column a vertical move carries from one wrapped row to the
next, so it is measured in cells rather than characters.")
  (:method ((renderer loom-renderer) string segment column)
    (let* ((start (car segment))
           (end (max start (min column (length string)))))
      (loom-renderer-string-width renderer (subseq string start end)))))

(defgeneric loom-renderer-segment-column (renderer string segment cells)
  (:documentation
   "Return the character column CELLS cells into SEGMENT of STRING.

The result is clamped to SEGMENT's end, which is what makes a vertical move
onto a shorter row land at that row's end rather than past it.")
  (:method ((renderer loom-renderer) string segment cells)
    (let* ((start (car segment))
           (end (cdr segment))
           (index start)
           (consumed 0))
      (loop while (< index end)
            for advance = (%loom-renderer-character-advance (char string index))
            do (when (> (+ consumed advance) cells)
                 (return))
               (incf consumed advance)
               (incf index))
      index)))

(defgeneric loom-renderer-clip-index (renderer string start-column)
  (:documentation
   "Locate STRING's first character visible past START-COLUMN screen cells.

Returns (VALUES INDEX LEADING-BLANK). INDEX is a character index, so callers
that already work in characters -- a tokenizer handing out substrings, for
one -- can slice without measuring again. LEADING-BLANK is the number of cells
between START-COLUMN and where INDEX actually begins: it is 1 when a
full-width character straddles START-COLUMN, because half of a character is
not drawable and the cell is left empty instead.")
  (:method ((renderer loom-renderer) string start-column)
    (check-type string string)
    (check-type start-column (integer 0 *))
    (let ((index 0)
          (consumed 0)
          (length (length string)))
      (loop while (and (< index length) (< consumed start-column))
            do (incf consumed
                     (%loom-renderer-character-advance (char string index)))
               (incf index))
      (values index (max 0 (- consumed start-column))))))

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
