;;;; packages/feature/file-tree/src/infrastructure-file-tree-directory-listing.lisp
;;;;
;;;; Infrastructure layer: the real, disk-backed directory listing entrypoint
;;;; for file-tree nodes.
;;;;
;;;; Most file-tree filesystem operations reach the disk through
;;;; *LOOM-FILESYSTEM*, a CL-BOUNDARY-KIT filesystem boundary, so
;;;; t/unit/filesystem-test.lisp can rebind that one variable to an
;;;; in-memory fake instead of creating a real temporary directory. Directory
;;;; listing deliberately stays on CL-HOST-KIT directly, because
;;;; CL-BOUNDARY-KIT:FILESYSTEM-LIST-DIRECTORY returns bare pathnames with no
;;;; entry classification. Recovering :DIRECTORY or :FILE through the boundary
;;;; would require a second probe per entry, whereas
;;;; CL-HOST-KIT:CALL-WITH-DIRECTORY-ENTRIES already reports the classification
;;;; in one pass.
;;;;
(in-package #:loom/feature/file-tree)

;;; ---------------------------------------------------------------------
;;; LOOM-FS-LIST-DIRECTORY: the real, disk-backed "children lister" for a
;;; file-tree directory node.
;;;
;;; domain/file-tree.lisp is deliberately pure tree state (visibility,
;;; selection, expand/collapse, the flattened FILE-TREE-ENTRIES listing) with
;;; no dependency on CL-HOST-KIT -- see that file's header comment. That
;;; means whatever populates a directory node's children from disk has to
;;; live here in infrastructure code instead; domain/file-tree.lisp calls
;;; into it through the FILE-TREE-CHILD-LISTER slot, a swappable
;;; function-of-one-argument seam that defaults to a pure,
;;; no-filesystem-access stub (%DEFAULT-CHILD-LISTER) so a FILE-TREE stays
;;; usable in isolation, e.g. in domain-layer tests.
;;;
;;; LOOM-FS-LIST-DIRECTORY below is written against PATH in and children out
;;; only, matching that seam's contract exactly, so wiring it into the real,
;;; disk-backed tree src/main.lisp builds is a single SETF (see
;;; %INITIALIZE-EDITOR-STATE):
;;;
;;;   (file-tree-install-child-lister file-tree #'loom-fs-list-directory)
;;; ---------------------------------------------------------------------
(defun loom-fs-list-directory (path)
  "Return the direct children of the directory at PATH as a list of
(CHILD-PATH . KIND) conses, where CHILD-PATH is an absolute pathname (as
yielded by CL-HOST-KIT:CALL-WITH-DIRECTORY-ENTRIES) and KIND is :DIRECTORY or
:FILE. Directories sort before files; within each group, entries sort
alphabetically by their namestrings. Symbolic links and other special entries
are omitted."
  (let ((directories '())
        (files '()))
    (host-kit:call-with-directory-entries
     (lambda (child-path metadata)
       (case (host-kit:file-metadata-kind metadata)
         (:directory (push (cons child-path :directory) directories))
         (:regular-file (push (cons child-path :file) files))
         (t nil)))
     path)
    (flet ((by-namestring< (a b)
             (string< (namestring (car a)) (namestring (car b)))))
      (append (sort (nreverse directories) #'by-namestring<)
              (sort (nreverse files) #'by-namestring<)))))
