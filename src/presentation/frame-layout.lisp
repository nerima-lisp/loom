(in-package #:loom)


(defun %layout-compute-regions (width height file-tree-visible-p)
  "Compute the row/column geometry COMPOSE-FRAME draws into, given the
renderer's WIDTH/HEIGHT and whether the file-tree sidebar is visible.
Returns (VALUES CONTENT-HEIGHT MINIBUFFER-ROW FILE-TREE-WIDTH
WINDOW-AREA-WIDTH), leaving COMPOSE-FRAME itself to only sequence the draw
calls against them."
  (let* ((content-height (max 0 (1- height)))
         (minibuffer-row (%layout-minibuffer-row height))
         (file-tree-width (%layout-file-tree-width file-tree-visible-p width))
         (window-area-width (max 0 (- width file-tree-width))))
    (values content-height minibuffer-row file-tree-width window-area-width)))

(defun %presentation-source-column (mapping display-column)
  (loop for source-column from 0 below (length mapping)
        when (> (aref mapping source-column) display-column)
          return (max 0 (1- source-column))
        finally (return (1- (length mapping)))))
(defun %presentation-hit-test-window-cell (screen-x screen-y window-x window-y width height)
  (when (and (<= window-x screen-x) (< screen-x (+ window-x width))
             (<= window-y screen-y) (< screen-y (+ window-y height)))
    (let ((row (- screen-y window-y))
          (column (- screen-x window-x)))
      (values row column
              (if (= row (1- height)) :mode-line :window-blank)))))

