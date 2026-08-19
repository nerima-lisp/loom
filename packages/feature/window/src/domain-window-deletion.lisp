;;;; packages/feature/window/src/domain-window-deletion.lisp
;;;;
;;;; Window-tree deletion operations. These mutate existing split nodes while
;;;; preserving selection and root layout invariants.
(in-package #:loom/feature/window)

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
