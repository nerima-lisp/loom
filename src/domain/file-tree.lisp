;;;; src/domain/file-tree.lisp
;;;;
;;;; Domain layer: the file-tree protocol's TREE-STATE generics only --
;;;; visibility, selection, expand/collapse, and the flattened visible-entry
;;;; listing. The generics that actually touch the filesystem
;;;; (FILE-TREE-CREATE-FILE, FILE-TREE-CREATE-DIRECTORY, FILE-TREE-RENAME,
;;;; FILE-TREE-DELETE, all wrapping CL-HOST-KIT) live in
;;;; infrastructure/filesystem.lisp instead, since they are I/O rather than
;;;; pure tree state.
;;;;
;;;; A file tree is the collapsible sidebar file browser rooted at a directory,
;;;; backed by CL-HOST-KIT for filesystem access.
(in-package #:loom)

;;; This domain layer has no dependency on CL-HOST-KIT, so it cannot itself
;;; list a directory's children. Instead FILE-TREE carries a CHILD-LISTER
;;; slot: a function of one argument PATH returning a list of (CHILD-PATH .
;;; :FILE-or-:DIRECTORY) conses, called lazily -- only for directories that
;;; are currently expanded (plus the root, whose direct children are always
;;; shown at depth 0). It defaults to a pure stub that reports every
;;; directory as childless, so a FILE-TREE is usable standalone (e.g. in
;;; tests) with no filesystem access at all. The infrastructure layer
;;; overrides it post-construction with the infrastructure lister, e.g.
;;;   (setf (file-tree-child-lister tree) #'loom-fs-list-directory)
;;; Expand/collapse state is a hash-table of currently-expanded directory
;;; paths (EQUAL-keyed, so string or pathname paths both work as long as a
;;; given tree is consistent about which it uses).
;;;
;;; FILE-TREE's own visibility and selection slots are named SHOWN and
;;; SELECTION rather than VISIBLE-P/SELECTED-PATH, so their auto-generated
;;; accessors (FILE-TREE-SHOWN, FILE-TREE-SELECTION) don't clash with the
;;; FILE-TREE-VISIBLE-P / FILE-TREE-SELECTED-PATH generic functions below.
;;; MAKE-FILE-TREE's default constructor name is likewise overridden
;;; (%MAKE-FILE-TREE) to avoid clashing with the MAKE-FILE-TREE generic
;;; function.

(defun %default-child-lister (path)
  "Default FILE-TREE-CHILD-LISTER: performs no filesystem access at all and
reports PATH as always having no children. Real directory listing is an
infrastructure concern (CL-HOST-KIT); this stub only keeps a fresh FILE-TREE
usable in isolation, e.g. in domain-layer tests."
  (declare (ignore path))
  nil)

(defstruct (file-tree (:constructor %make-file-tree))
  root-path
  (shown nil)
  (expanded (make-hash-table :test #'equal))
  selection
  (child-lister #'%default-child-lister))

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

(defgeneric make-file-tree (root-path)
  (:documentation
   "Create and return a new file tree rooted at ROOT-PATH. The tree is
initially not visible (see FILE-TREE-VISIBLE-P) and every directory starts
collapsed.")
  (:method (root-path)
    (%make-file-tree :root-path root-path)))

(defgeneric file-tree-visible-p (tree)
  (:documentation "Return true if TREE's sidebar is currently shown.")
  (:method (tree)
    (file-tree-shown tree)))

(defgeneric file-tree-toggle (tree)
  (:documentation
   "Toggle whether TREE's sidebar is shown, flipping FILE-TREE-VISIBLE-P.
Returns the new visibility state.")
  (:method (tree)
    (setf (file-tree-shown tree) (not (file-tree-shown tree)))))

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
