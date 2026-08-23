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

(defgeneric window-split (tree window direction)
  (:documentation
   "Split WINDOW (a leaf window of TREE) into two windows along DIRECTION,
which is :HORIZONTAL (stacking the two windows top/bottom, i.e. C-x 2) or
:VERTICAL (placing the two windows side by side, i.e. C-x 3). Both resulting
windows initially display the same buffer WINDOW displayed. Selection moves
to the newly created window. Returns the newly created window.")
  (:method (tree window direction)
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
              leaf2)))))))

(defgeneric window-select-next (tree)
  (:documentation
   "Select the next window in TREE, cycling back to the first after the
last (C-x o). Returns the newly selected window.")
  (:method (tree)
    (let* ((windows (%window-collect-leaves (window-tree-root tree)))
           (n (length windows))
           (pos (position (window-tree-selected tree) windows)))
      (let ((next (nth (mod (1+ (or pos 0)) n) windows)))
        (setf (window-tree-selected tree) next)
        next))))

(defgeneric window-buffer (window)
  (:documentation "Return the buffer currently displayed in WINDOW.")
  (:method (window)
    (window-leaf-buffer window)))

(defgeneric window-set-buffer (window buffer)
  (:documentation
   "Display BUFFER in WINDOW (C-x b), replacing whatever buffer it
previously displayed. Returns WINDOW.")
  (:method (window buffer)
    (setf (window-leaf-buffer window) buffer
          (window-leaf-scroll-line window) 0
          (window-leaf-scroll-column window) 0)
    window))

(defgeneric window-scroll-line (window)
  (:documentation
   "Return WINDOW's zero-based first visible buffer line.")
  (:method (window)
    (window-leaf-scroll-line window)))

(defgeneric (setf window-scroll-line) (line window)
  (:documentation
   "Set WINDOW's zero-based first visible buffer LINE.")
  (:method (line window)
    (setf (window-leaf-scroll-line window) (max 0 line))))

(defgeneric window-scroll-column (window)
  (:documentation
   "Return WINDOW's leftmost visible screen column.

This counts terminal cells, not buffer characters, so it stays comparable
with the column a full-width character occupies.")
  (:method (window)
    (window-leaf-scroll-column window)))

(defgeneric (setf window-scroll-column) (column window)
  (:documentation
   "Set WINDOW's leftmost visible screen COLUMN.")
  (:method (column window)
    (setf (window-leaf-scroll-column window) (max 0 column))))

(defgeneric window-tree-resize (tree width height)
  (:documentation
   "Resize TREE to the given WIDTH and HEIGHT (terminal columns and rows,
typically in response to a terminal resize event), re-laying-out every
window in TREE proportionally. Returns TREE.")
  (:method (tree width height)
    (setf (window-tree-width tree) width
          (window-tree-height tree) height)
    (%window-layout (window-tree-root tree) 0 0 width height)
    tree))
