;;;; src/presentation/layout-windows.lisp
;;;;
;;;; Presentation of window buffers, separators, and matching parentheses.
(in-package #:loom)

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

(defun %layout-draw-windows (renderer window-tree x-offset)
  "Draw every leaf window and the separators in WINDOW-TREE."
  (let ((leaves (loom/feature/window:window-tree-windows window-tree)))
    (dolist (leaf leaves)
      (%layout-draw-window-buffer renderer leaf x-offset)
      (%layout-draw-matching-paren renderer leaf x-offset)
      (%layout-draw-isearch renderer leaf x-offset)
      (%layout-draw-completion renderer leaf x-offset))
    (dolist (leaf leaves)
      (when (and (plusp (loom/feature/window:window-x leaf))
                 (plusp (loom/feature/window:window-height leaf)))
        (loom-renderer-draw-vertical-line
         renderer (1- (+ x-offset (loom/feature/window:window-x leaf)))
         (loom/feature/window:window-y leaf)
         (loom/feature/window:window-height leaf)))
      (when (and (plusp (loom/feature/window:window-y leaf))
                 (plusp (loom/feature/window:window-width leaf)))
        (loom-renderer-draw-horizontal-line
         renderer (+ x-offset (loom/feature/window:window-x leaf))
         (1- (loom/feature/window:window-y leaf))
         (loom/feature/window:window-width leaf))))
    renderer))

(defparameter +layout-matching-paren-style+ '(:bold (:bg 5) (:fg 0))
  "Style marking the parenthesis at point and the one it pairs with.")

(defun %layout-draw-matching-paren (renderer window x-offset)
  "Mark the parenthesis point is adjacent to, together with its partner."
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
