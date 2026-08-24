;;;; packages/feature/syntax-highlighting/src/presentation-syntax-highlighting.lisp
;;;;
;;;; Presentation-layer mapping from semantic syntax tokens to terminal
;;;; styles.  The tokenizer stays in the domain layer; this file is the only
;;;; place that chooses the visual treatment for each token kind.

(in-package #:loom/feature/syntax-highlighting)

(defparameter +layout-syntax-styles+
  '((:comment . (:fg 8))
    (:string . (:fg 2))
    (:keyword . (:bold (:fg 6)))
    (:number . (:fg 3))
    (:delimiter . (:fg 4)))
  "Terminal styles associated with syntax token kinds.")

(defun %layout-syntax-style (kind)
  (cdr (assoc kind +layout-syntax-styles+)))

(defun syntax-draw-highlighted-line (renderer line x y width
                                      &optional (mode :common-lisp)
                                                (start-column 0))
  "Draw LINE at (X, Y), preserving token text and fitting WIDTH cells.

START-COLUMN scrolls the viewport right by that many screen cells. The line is
still tokenized whole -- clipping the text first would change what the
tokenizer sees, turning a cut string literal into something else -- and each
token is then sliced at the character index LOOM-RENDERER-CLIP-INDEX reports,
so no token is measured twice and no full-width character is drawn in half."
  (multiple-value-bind (start-index leading-blank)
      (loom-renderer-clip-index renderer line start-column)
    (let ((column (+ x leading-blank))
          (remaining (max 0 (- width leading-blank)))
          (character-index 0))
      (dolist (token (syntax-highlight-line-for-mode line mode))
        (let* ((text (syntax-token-text token))
               (end (+ character-index (length text))))
          (when (and (plusp remaining) (> end start-index))
            (let* ((slice (if (> start-index character-index)
                              (subseq text (- start-index character-index))
                              text))
                   (visible (loom-renderer-truncate-string
                             renderer slice remaining))
                   (visible-width (loom-renderer-string-width renderer visible)))
              (unless (zerop (length visible))
                (loom-renderer-write-string
                 renderer column y visible
                 :style (%layout-syntax-style (syntax-token-kind token)))
                (incf column visible-width)
                (decf remaining visible-width))))
          (setf character-index end)))))
  renderer)

(defun syntax-draw-buffer (renderer buffer x y width height
                           &key (start-line 0) (start-column 0))
  "Draw BUFFER's visible lines with line-local syntax styles."
  (let ((line-count (buffer-visible-line-count buffer)))
    (dotimes (row height)
      (let ((line-number (+ start-line row)))
        (when (< line-number line-count)
          (syntax-draw-highlighted-line
           renderer
           (buffer-visible-line buffer line-number)
           x
           (+ y row)
           width
           (buffer-major-mode buffer)
           start-column)))))
  renderer)
