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
