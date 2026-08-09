;;;; packages/feature/window/src/domain-window-operations.lisp
;;;;
;;;; Window-tree operations: split, select, delete, buffer switching, and
;;;; resize. These operations depend on the data model and layout protocol in
;;;; domain-window.lisp, but remain separate from that representation.
(in-package #:loom/feature/window)

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

(defun %window-first-leaf (node)
  "Return the first leaf below NODE in depth-first order."
  (if (window-leaf-p node)
      node
      (%window-first-leaf (first (window-split-node-children node)))))

(defun %window-delete-node (node target)
  "Return NODE with TARGET removed, plus whether TARGET was found."
  (if (window-leaf-p node)
      (values node nil)
      (let* ((children (window-split-node-children node))
             (first-child (first children))
             (second-child (second children)))
        (cond
          ((eq first-child target)
           (values second-child t))
          ((eq second-child target)
           (values first-child t))
          (t
           (multiple-value-bind (new-first deleted-first)
               (%window-delete-node first-child target)
             (if deleted-first
                 (progn
                   (setf (first children) new-first)
                   (values node t))
                 (multiple-value-bind (new-second deleted-second)
                     (%window-delete-node second-child target)
                   (when deleted-second
                     (setf (second children) new-second))
                   (values node deleted-second)))))))))

(defgeneric window-delete (tree window)
  (:documentation
   "Delete WINDOW from TREE when another window remains. Returns the
selected window after the deletion; deleting the sole window is a no-op.")
  (:method (tree window)
    (let ((selected (window-tree-selected tree)))
      (when (> (length (window-tree-windows tree)) 1)
        (multiple-value-bind (new-root deleted)
            (%window-delete-node (window-tree-root tree) window)
          (when deleted
            (setf (window-tree-root tree) new-root
                  (window-tree-selected tree)
                  (if (eq selected window)
                      (%window-first-leaf new-root)
                      selected))
            (%window-layout (window-tree-root tree)
                            0 0
                            (window-tree-width tree)
                            (window-tree-height tree)))))
      (window-tree-selected tree))))

(defgeneric window-delete-other-windows (tree window)
  (:documentation
   "Delete every window in TREE except WINDOW and return WINDOW.")
  (:method (tree window)
    (setf (window-tree-root tree) window
          (window-tree-selected tree) window)
    (%window-layout window 0 0
                    (window-tree-width tree)
                    (window-tree-height tree))
    window))

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
          (window-leaf-scroll-line window) 0)
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

(defgeneric window-x (window)
  (:documentation
   "Return WINDOW's left edge, in terminal columns, relative to its window
tree's origin.")
  (:method (window)
    (window-leaf-x window)))

(defgeneric window-y (window)
  (:documentation
   "Return WINDOW's top edge, in terminal rows, relative to its window
tree's origin.")
  (:method (window)
    (window-leaf-y window)))

(defgeneric window-width (window)
  (:documentation "Return WINDOW's width in terminal columns.")
  (:method (window)
    (window-leaf-width window)))

(defgeneric window-height (window)
  (:documentation "Return WINDOW's height in terminal rows.")
  (:method (window)
    (window-leaf-height window)))

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
