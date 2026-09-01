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

(defun %window-delete-child (node target)
  (let* ((children (window-split-node-children node))
         (first-child (first children))
         (second-child (second children)))
    (cond
      ((eq first-child target) (values second-child t))
      ((eq second-child target) (values first-child t))
      (t (values nil nil)))))

(defun %window-delete-from-subtree (node target child-index)
  (let ((children (window-split-node-children node)))
    (multiple-value-bind (new-child deleted)
        (%window-delete-node (nth child-index children) target)
      (when deleted
        (setf (nth child-index children) new-child))
      (values node deleted))))

(defun %window-delete-node (node target)
  "Return NODE with TARGET removed, plus whether TARGET was found."
  (if (window-leaf-p node)
      (values node nil)
      (multiple-value-bind (replacement deleted)
          (%window-delete-child node target)
        (if deleted
            (values replacement t)
            (multiple-value-bind (new-node deleted-in-first)
                (%window-delete-from-subtree node target 0)
              (if deleted-in-first
                  (values new-node t)
                  (%window-delete-from-subtree node target 1)))))))

(defun window-delete (tree window)
  "Delete WINDOW from TREE when another window remains. Returns the
selected window after the deletion; deleting the sole window is a no-op."
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
    (window-tree-selected tree)))

(defun window-delete-other-windows (tree window)
  "Delete every window in TREE except WINDOW and return WINDOW."
  (setf (window-tree-root tree) window
        (window-tree-selected tree) window)
  (%window-layout window 0 0
                  (window-tree-width tree)
                  (window-tree-height tree))
  window)
