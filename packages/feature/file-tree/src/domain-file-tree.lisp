(in-package #:loom/feature/file-tree)


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

(defun file-tree-install-child-lister (tree lister)
  "Install LISTER as TREE's child-directory provider and return TREE.
LISTER receives one pathname and returns the children for that directory."
  (setf (file-tree-child-lister tree) lister)
  tree)

(defun file-tree-prefetch-paths (tree)
  "Return TREE's root and currently expanded directories for prefetching."
  (cons (file-tree-root-path tree)
        (loop for path being the hash-keys of
                (file-tree-expanded tree)
              collect path)))

(defun make-file-tree (root-path)
  "Create and return a new file tree rooted at ROOT-PATH. The tree is
initially not visible (see FILE-TREE-VISIBLE-P) and every directory starts
collapsed."
  (%make-file-tree :root-path root-path))

(defun file-tree-visible-p (tree)
  "Return true if TREE's sidebar is currently shown."
  (file-tree-shown tree))

(defun file-tree-toggle (tree)
  "Toggle whether TREE's sidebar is shown, flipping FILE-TREE-VISIBLE-P.
Returns the new visibility state."
  (setf (file-tree-shown tree) (not (file-tree-shown tree))))
