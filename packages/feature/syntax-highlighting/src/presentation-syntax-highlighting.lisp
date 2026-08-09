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

(defun %layout-draw-highlighted-line (renderer line x y width
                                       &optional (mode :common-lisp))
  "Draw LINE at (X, Y), preserving token text and fitting WIDTH cells."
  (let ((column x)
        (remaining width))
    (dolist (token (syntax-highlight-line-for-mode line mode))
      (when (plusp remaining)
        (let* ((text (syntax-token-text token))
               (visible (loom-renderer-truncate-string
                         renderer text remaining))
               (visible-width (loom-renderer-string-width renderer visible)))
          (unless (zerop (length visible))
            (loom-renderer-write-string
             renderer column y visible
             :style (%layout-syntax-style (syntax-token-kind token)))
            (incf column visible-width)
            (decf remaining visible-width))))))
    renderer)

(defun %layout-draw-buffer (renderer buffer x y width height &key (start-line 0))
  "Draw BUFFER's visible lines with line-local syntax styles."
  (let ((line-count (buffer-line-count buffer)))
    (dotimes (row height)
      (let ((line-number (+ start-line row)))
        (when (< line-number line-count)
          (%layout-draw-highlighted-line
           renderer
           (buffer-line buffer line-number)
           x
           (+ y row)
           width
           (buffer-major-mode buffer))))))
  renderer)
