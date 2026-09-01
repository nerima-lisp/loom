;;;; packages/feature/file-tree/src/domain-file-tree-navigation.lisp
;;;;
;;;; Domain layer: visible-entry enumeration and selection / expand-collapse
;;;; navigation for FILE-TREE state.
(in-package #:loom/feature/file-tree)

(defun %file-tree-flatten (tree path depth active-paths)
  "Return the depth-first flattening of PATH's children (at DEPTH) and, for
each child directory currently in TREE's expanded set, its children in turn,
recursing only into expanded directories."
  (unless (gethash path active-paths)
    (setf (gethash path active-paths) t)
    (unwind-protect
         (loop for (child-path . kind) in (funcall (file-tree-child-lister tree) path)
             append (cons (cons child-path depth)
                          (when (and (eq kind :directory)
                                     (gethash child-path (file-tree-expanded tree)))
                            (%file-tree-flatten tree child-path (1+ depth)
                                                 active-paths))))
      (remhash path active-paths))))

(defun %file-tree-child-kind (path children)
  (cdr (assoc path children :test (function equal))))

(defun %file-tree-find-kind (tree path)
  "Search TREE, following only currently-expanded directories starting from
its root, for an entry whose path is EQUAL to PATH, and return its kind
(:FILE or :DIRECTORY), or NIL if PATH is not found among the currently
reachable (visible) entries."
  (let ((active-paths (make-hash-table :test #'equal)))
    (labels ((search-under (dir-path)
               (unless (gethash dir-path active-paths)
                 (setf (gethash dir-path active-paths) t)
                 (unwind-protect
                      (let ((children (funcall (file-tree-child-lister tree) dir-path)))
                        (or (%file-tree-child-kind path children)
                            (loop for (child-path . kind) in children
                                  thereis (and (eq kind :directory)
                                               (gethash child-path (file-tree-expanded tree))
                                               (search-under child-path)))))
                   (remhash dir-path active-paths)))))
      (search-under (file-tree-root-path tree)))))

(defun file-tree-entries (tree)
  "Return the flattened list of currently visible entries in TREE,
respecting each directory's expand/collapse state, as a list of (PATH .
DEPTH) conses in display order. DEPTH is a non-negative integer: ROOT-PATH's
direct children are at depth 0."
  (%file-tree-flatten tree (file-tree-root-path tree) 0
                      (make-hash-table :test #'equal)))

(defun file-tree-selected-path (tree)
  "Return the path of TREE's currently selected entry, or NIL if nothing
is selected (e.g. an empty tree)."
  (file-tree-selection tree))

(defun file-tree-entry-kind (tree path)
  "Return :FILE or :DIRECTORY for PATH in TREE, or NIL when PATH is not
reachable in TREE."
  (%file-tree-find-kind tree path))

(defun %file-tree-selection-position (paths selected-path)
  (position selected-path paths :test #'equal))

(defun %file-tree-position-at-boundary (paths direction)
  (if (eq direction :down)
      0
      (1- (length paths))))

(defun %file-tree-move-selection-position (position count direction)
  (ecase direction
    (:down (min (1- count) (1+ position)))
    (:up (max 0 (1- position)))))

(defun %file-tree-next-selection (paths selected-path direction)
  "Return the visible PATH selected after moving in DIRECTION.

The calculation is independent of FILE-TREE state so callers can keep the
selection mutation at the boundary and test navigation as a pure operation."
  (let ((count (length paths)))
    (when (plusp count)
      (let* ((position (%file-tree-selection-position paths selected-path))
             (next-position
               (if position
                   (%file-tree-move-selection-position
                    position count direction)
                   (%file-tree-position-at-boundary paths direction))))
        (nth next-position paths)))))

(defun file-tree-move-selection (tree direction)
  "Move TREE's selection cursor by one visible entry (see
FILE-TREE-ENTRIES) in DIRECTION, which is :UP or :DOWN. A no-op at either
end of the visible entry list. Returns the newly selected path."
  (let ((paths (mapcar #'car (file-tree-entries tree))))
    (setf (file-tree-selection tree)
          (%file-tree-next-selection paths
                                     (file-tree-selection tree)
                                     direction))))

(defun file-tree-toggle-expand (tree path)
  "Toggle the expand/collapse state of the directory at PATH within TREE,
changing which entries FILE-TREE-ENTRIES subsequently returns. Signals an
error if PATH does not name a directory in TREE. Returns the new
expanded-p state."
  (unless (eq (%file-tree-find-kind tree path) :directory)
    (error "not a directory in tree: ~S" path))
  (unless (remhash path (file-tree-expanded tree))
    (setf (gethash path (file-tree-expanded tree)) t))
  (and (gethash path (file-tree-expanded tree)) t))
