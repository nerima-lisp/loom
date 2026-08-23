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

;;; ---------------------------------------------------------------------
;;; Window-tree area
;;; ---------------------------------------------------------------------

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
      (loom/feature/syntax-highlighting:syntax-draw-buffer
       renderer (loom/feature/window:window-buffer leaf)
       (+ x-offset (loom/feature/window:window-x leaf))
       (loom/feature/window:window-y leaf)
       (loom/feature/window:window-width leaf)
       (loom/feature/window:window-height leaf)
       :start-line (loom/feature/window:window-scroll-line leaf)))
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
