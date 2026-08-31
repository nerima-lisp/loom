;;;; packages/feature/window/src/domain-window-operations.lisp
;;;;
;;;; Window-tree split, selection, buffer, and resize operations. Window
;;;; deletion lives in domain-window-deletion.lisp so tree surgery remains
;;;; isolated from the rest of the mutation protocol.
(in-package #:loom/feature/window)

(defun %window-replace (node target replacement)
  "Return NODE with the subtree EQ to TARGET replaced by REPLACEMENT,
mutating WINDOW-SPLIT-NODE children in place as it descends."
  (cond
    ((eq node target) replacement)
    ((window-split-node-p node)
     (setf (window-split-node-children node)
           (mapcar (lambda (child) (%window-replace child target replacement))
                   (window-split-node-children node)))
     node)
    (t node)))

(defun window-split (tree window direction)
  "Split WINDOW (a leaf window of TREE) into two windows along DIRECTION,
which is :HORIZONTAL (stacking the two windows top/bottom, i.e. C-x 2) or
:VERTICAL (placing the two windows side by side, i.e. C-x 3). Both resulting
windows initially display the same buffer WINDOW displayed. Selection moves
to the newly created window. Returns the newly created window."
  (let ((buffer (window-leaf-buffer window)))
      (multiple-value-bind (rect1 rect2)
          (%window-split-rects (window-leaf-x window) (window-leaf-y window)
                                (window-leaf-width window) (window-leaf-height window)
                                direction)
        (destructuring-bind (x1 y1 w1 h1) rect1
          (destructuring-bind (x2 y2 w2 h2) rect2
            ;; WINDOW is mutated in place to become the first half, rather
            ;; than being discarded in favor of a fresh struct, so that any
            ;; reference to it a caller already holds stays valid -- and
            ;; correctly reflects the post-split size -- instead of becoming
            ;; silently stale. %WINDOW-REPLACE below still finds it by EQ,
            ;; which mutating its slots does not affect.
            (setf (window-leaf-x window) x1
                  (window-leaf-y window) y1
                  (window-leaf-width window) w1
                  (window-leaf-height window) h1)
            (let* ((leaf2 (make-window-leaf :buffer buffer :x x2 :y y2 :width w2 :height h2))
                   (split-node (make-window-split-node :direction direction
                                                        :children (list window leaf2))))
              (setf (window-tree-root tree)
                    (%window-replace (window-tree-root tree) window split-node))
              (setf (window-tree-selected tree) leaf2)
              leaf2))))))

(defun window-select-next (tree)
  "Select the next window in TREE, cycling back to the first after the
last (C-x o). Returns the newly selected window."
  (let* ((windows (%window-collect-leaves (window-tree-root tree)))
         (n (length windows))
         (pos (position (window-tree-selected tree) windows)))
    (let ((next (nth (mod (1+ (or pos 0)) n) windows)))
      (setf (window-tree-selected tree) next)
      next)))

(defun window-buffer (window)
  "Return the buffer currently displayed in WINDOW."
  (window-leaf-buffer window))

(defun window-set-buffer (window buffer)
  "Display BUFFER in WINDOW (C-x b), replacing whatever buffer it
previously displayed. Returns WINDOW."
  (setf (window-leaf-buffer window) buffer
        (window-leaf-scroll-line window) 0
        (window-leaf-scroll-column window) 0
        (window-leaf-scroll-sub-row window) 0)
  window)

(defun window-scroll-line (window)
  "Return WINDOW's zero-based first visible buffer line."
  (window-leaf-scroll-line window))

(defun (setf window-scroll-line) (line window)
  "Set WINDOW's zero-based first visible buffer LINE."
  (setf (window-leaf-scroll-line window) (max 0 line)))

(defun window-scroll-column (window)
  "Return WINDOW's leftmost visible screen column.

This counts terminal cells, not buffer characters, so it stays comparable
with the column a full-width character occupies."
  (window-leaf-scroll-column window))

(defun (setf window-scroll-column) (column window)
  "Set WINDOW's leftmost visible screen COLUMN."
  (setf (window-leaf-scroll-column window) (max 0 column)))

(defun window-scroll-sub-row (window)
  "Return which wrapped segment of WINDOW's scroll line is on its first row."
  (window-leaf-scroll-sub-row window))

(defun (setf window-scroll-sub-row) (row window)
  "Set which wrapped segment of WINDOW's scroll line is on its first ROW."
  (setf (window-leaf-scroll-sub-row window) (max 0 row)))

(defun window-tree-resize (tree width height)
  "Resize TREE to the given WIDTH and HEIGHT (terminal columns and rows,
typically in response to a terminal resize event), re-laying-out every
window in TREE proportionally. Returns TREE."
  (setf (window-tree-width tree) width
        (window-tree-height tree) height)
  (%window-layout (window-tree-root tree) 0 0 width height)
  tree)
