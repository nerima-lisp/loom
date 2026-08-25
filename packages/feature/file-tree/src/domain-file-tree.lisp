;;;; packages/feature/file-tree/src/domain-file-tree.lisp
;;;;
;;;; Domain layer: file-tree state construction, visibility, and child-lister
;;;; installation. Visible-entry enumeration and selection / expand-collapse
;;;; navigation live in domain-file-tree-navigation.lisp. The generics that
;;;; actually touch the filesystem
;;;; (FILE-TREE-CREATE-FILE, FILE-TREE-CREATE-DIRECTORY, FILE-TREE-RENAME,
;;;; FILE-TREE-DELETE, all wrapping CL-HOST-KIT) live in
;;;; infrastructure/filesystem.lisp instead, since they are I/O rather than
;;;; pure tree state.
;;;;
;;;; A file tree is the collapsible sidebar file browser rooted at a directory,
;;;; backed by CL-HOST-KIT for filesystem access.
(in-package #:loom/feature/file-tree)

;;; This domain layer has no dependency on CL-HOST-KIT, so it cannot itself
;;; list a directory's children. Instead FILE-TREE carries a CHILD-LISTER
;;; slot: a function of one argument PATH returning a list of (CHILD-PATH .
;;; :FILE-or-:DIRECTORY) conses, called lazily -- only for directories that
;;; are currently expanded (plus the root, whose direct children are always
;;; shown at depth 0). It defaults to a pure stub that reports every
;;; directory as childless, so a FILE-TREE is usable standalone (e.g. in
;;; tests) with no filesystem access at all. The infrastructure layer
;;; overrides it post-construction with the infrastructure lister, e.g.
;;; The infrastructure layer installs LOOM-FS-LIST-DIRECTORY as the lister.
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

(defgeneric file-tree-install-child-lister (tree lister)
  (:documentation
   "Install LISTER as TREE's child-directory provider and return TREE.
LISTER receives one pathname and returns the children for that directory.")
  (:method (tree lister)
    (setf (file-tree-child-lister tree) lister)
    tree))

(defgeneric file-tree-prefetch-paths (tree)
  (:documentation
   "Return TREE's root and currently expanded directories for prefetching.")
  (:method (tree)
    (cons (file-tree-root-path tree)
          (loop for path being the hash-keys of
                  (file-tree-expanded tree)
                collect path))))

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
