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

(defun loom-renderer-string-width (renderer string)
  "Return STRING's width in the screen-cell coordinates of RENDERER."
  (declare (ignore renderer))
  (check-type string string)
  (loop for character across string
        sum (%loom-renderer-character-advance character)))

(defun loom-renderer-clip-index (renderer string start-column)
  "Locate STRING's first character visible past START-COLUMN screen cells.

Returns (VALUES INDEX LEADING-BLANK). INDEX is a character index, so callers
that already work in characters -- a tokenizer handing out substrings, for
one -- can slice without measuring again. LEADING-BLANK is the number of cells
between START-COLUMN and where INDEX actually begins: it is 1 when a
full-width character straddles START-COLUMN, because half of a character is
not drawable and the cell is left empty instead."
  (declare (ignore renderer))
  (check-type string string)
    (check-type start-column (integer 0 *))
    (let ((index 0)
          (consumed 0)
          (length (length string)))
      (loop while (and (< index length) (< consumed start-column))
            do (incf consumed
                     (%loom-renderer-character-advance (char string index)))
               (incf index))
    (values index (max 0 (- consumed start-column)))))

(defun loom-renderer-truncate-string (renderer string width)
  "Return the longest prefix of STRING that fits WIDTH screen cells."
  (declare (ignore renderer))
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
        (subseq string 0 position))))
