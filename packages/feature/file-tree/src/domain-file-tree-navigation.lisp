;;;; packages/feature/file-tree/src/domain-file-tree-navigation.lisp
;;;;
;;;; Domain layer: visible-entry enumeration and selection / expand-collapse
;;;; navigation for FILE-TREE state.
(in-package #:loom/feature/file-tree)

(defun %file-tree-flatten-child (tree child-path kind depth active-paths)
  (cons (cons child-path depth)
        (when (%file-tree-expanded-directory-p tree child-path kind)
          (%file-tree-flatten tree child-path (1+ depth) active-paths))))

(defun %file-tree-flatten-children (tree path depth active-paths)
  (loop for (child-path . kind) in
        (funcall (file-tree-child-lister tree) path)
        append (%file-tree-flatten-child tree child-path kind depth
                                         active-paths)))

(defun %file-tree-flatten (tree path depth active-paths)
  "Return the depth-first flattening of PATH's children (at DEPTH) and, for
each child directory currently in TREE's expanded set, its children in turn,
recursing only into expanded directories."
  (unless (gethash path active-paths)
    (setf (gethash path active-paths) t)
    (unwind-protect
         (%file-tree-flatten-children tree path depth active-paths)
      (remhash path active-paths))))

(defun %file-tree-child-kind (path children)
  (cdr (assoc path children :test (function equal))))

(defun %file-tree-expanded-directory-p (tree path kind)
  (and (eq kind :directory)
       (gethash path (file-tree-expanded tree))))

(defun %file-tree-search-children (tree path children active-paths)
  (or (%file-tree-child-kind path children)
      (loop for (child-path . kind) in children
            thereis (when (%file-tree-expanded-directory-p tree child-path kind)
                      (%file-tree-search-directory tree path child-path
                                                   active-paths)))))

(defun %file-tree-search-directory (tree target-path directory-path active-paths)
  (unless (gethash directory-path active-paths)
    (setf (gethash directory-path active-paths) t)
    (unwind-protect
         (%file-tree-search-children
          tree target-path
          (funcall (file-tree-child-lister tree) directory-path)
          active-paths)
      (remhash directory-path active-paths))))

(defun %file-tree-find-kind (tree path)
  "Search TREE, following only currently-expanded directories starting from
its root, for an entry whose path is EQUAL to PATH, and return its kind
  (:FILE or :DIRECTORY), or NIL if PATH is not found among the currently
  reachable (visible) entries."
  (%file-tree-search-directory tree path (file-tree-root-path tree)
                               (make-hash-table :test #'equal)))

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

(defun %file-tree-next-position (paths selected-path direction)
  (let ((count (length paths)))
    (when (plusp count)
      (let ((position (%file-tree-selection-position paths selected-path)))
        (if position
            (%file-tree-move-selection-position position count direction)
            (%file-tree-position-at-boundary paths direction))))))

(defun %file-tree-next-selection (paths selected-path direction)
  "Return the visible PATH selected after moving in DIRECTION.

The calculation is independent of FILE-TREE state so callers can keep the
selection mutation at the boundary and test navigation as a pure operation."
  (let ((next-position (%file-tree-next-position paths selected-path direction)))
    (when next-position
      (nth next-position paths))))

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
  (and (not (remhash path (file-tree-expanded tree)))
       (setf (gethash path (file-tree-expanded tree)) t)))
