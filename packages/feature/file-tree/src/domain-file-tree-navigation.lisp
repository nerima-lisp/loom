;;;; packages/feature/file-tree/src/domain-file-tree-navigation.lisp
;;;;
;;;; Domain layer: visible-entry enumeration and selection / expand-collapse
;;;; navigation for FILE-TREE state.
(in-package #:loom/feature/file-tree)

(defun %file-tree-flatten (tree path depth)
  "Return the depth-first flattening of PATH's children (at DEPTH) and, for
each child directory currently in TREE's expanded set, its children in turn,
recursing only into expanded directories."
  (loop for (child-path . kind) in (funcall (file-tree-child-lister tree) path)
        append (cons (cons child-path depth)
                     (when (and (eq kind :directory)
                                (gethash child-path (file-tree-expanded tree)))
                       (%file-tree-flatten tree child-path (1+ depth))))))

(defun %file-tree-find-kind (tree path)
  "Search TREE, following only currently-expanded directories starting from
its root, for an entry whose path is EQUAL to PATH, and return its kind
(:FILE or :DIRECTORY), or NIL if PATH is not found among the currently
reachable (visible) entries."
  (labels ((search-under (dir-path)
             (let ((children (funcall (file-tree-child-lister tree) dir-path)))
               (or (cdr (assoc path children :test (function equal)))
                   (loop for (child-path . kind) in children
                         thereis (and (eq kind :directory)
                                      (gethash child-path (file-tree-expanded tree))
                                      (search-under child-path)))))))
    (search-under (file-tree-root-path tree))))

(defgeneric file-tree-entries (tree)
  (:documentation
   "Return the flattened list of currently visible entries in TREE,
respecting each directory's expand/collapse state, as a list of (PATH .
DEPTH) conses in display order. DEPTH is a non-negative integer: ROOT-PATH's
direct children are at depth 0.")
  (:method (tree)
    (%file-tree-flatten tree (file-tree-root-path tree) 0)))

(defgeneric file-tree-selected-path (tree)
  (:documentation
   "Return the path of TREE's currently selected entry, or NIL if nothing
is selected (e.g. an empty tree).")
  (:method (tree)
    (file-tree-selection tree)))

(defgeneric file-tree-entry-kind (tree path)
  (:documentation
   "Return :FILE or :DIRECTORY for PATH in TREE, or NIL when PATH is not
reachable in TREE.")
  (:method (tree path)
    (%file-tree-find-kind tree path)))

(defgeneric file-tree-move-selection (tree direction)
  (:documentation
   "Move TREE's selection cursor by one visible entry (see
FILE-TREE-ENTRIES) in DIRECTION, which is :UP or :DOWN. A no-op at either
end of the visible entry list. Returns the newly selected path.")
  (:method (tree direction)
    (let* ((paths (mapcar #'car (file-tree-entries tree)))
           (n (length paths)))
      (setf (file-tree-selection tree)
            (if (zerop n)
                nil
                (let ((pos (position (file-tree-selection tree) paths :test #'equal)))
                  (cond
                    ((null pos) (if (eq direction :down) (first paths) (car (last paths))))
                    ((eq direction :down) (nth (min (1- n) (1+ pos)) paths))
                    ((eq direction :up) (nth (max 0 (1- pos)) paths))
                    (t (error "unknown direction: ~A" direction)))))))))

(defgeneric file-tree-toggle-expand (tree path)
  (:documentation
   "Toggle the expand/collapse state of the directory at PATH within TREE,
changing which entries FILE-TREE-ENTRIES subsequently returns. Signals an
error if PATH does not name a directory in TREE. Returns the new
expanded-p state.")
  (:method (tree path)
    (unless (eq (%file-tree-find-kind tree path) :directory)
      (error "not a directory in tree: ~S" path))
    (if (gethash path (file-tree-expanded tree))
        (remhash path (file-tree-expanded tree))
        (setf (gethash path (file-tree-expanded tree)) t))
    (and (gethash path (file-tree-expanded tree)) t)))
