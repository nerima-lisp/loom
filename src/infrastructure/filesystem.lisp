;;;; src/infrastructure/filesystem.lisp
;;;;
;;;; Infrastructure layer: the file-tree protocol's disk-touching generics,
;;;; split out of the tree-state generics in domain/file-tree.lisp because
;;;; these four operate on the real filesystem via CL-HOST-KIT rather than on
;;;; pure tree state. Generic names are unchanged from the original flat
;;;; src/protocol.lisp; only the file they live in changed.
(in-package #:loom)

;;; ---------------------------------------------------------------------
;;; LOOM-FS-LIST-DIRECTORY: the real, disk-backed "children lister" for a
;;; file-tree directory node.
;;;
;;; domain/file-tree.lisp is deliberately pure tree state (visibility,
;;; selection, expand/collapse, the flattened FILE-TREE-ENTRIES listing) with
;;; no dependency on CL-HOST-KIT -- see that file's header comment. That
;;; means whatever populates a directory node's children from disk has to
;;; live here in infrastructure/filesystem.lisp instead; domain/file-tree.lisp
;;; calls into it through the FILE-TREE-CHILD-LISTER slot, a swappable
;;; function-of-one-argument seam that defaults to a pure, no-filesystem-
;;; access stub (%DEFAULT-CHILD-LISTER) so a FILE-TREE stays usable in
;;; isolation, e.g. in domain-layer tests.
;;;
;;; LOOM-FS-LIST-DIRECTORY below is written against PATH in and children out
;;; only, matching that seam's contract exactly, so wiring it into the real,
;;; disk-backed tree src/main.lisp builds is a single SETF (see
;;; %INITIALIZE-EDITOR-STATE):
;;;
;;;   (setf (file-tree-child-lister file-tree) #'loom-fs-list-directory)
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

;;; Each of the four generics below performs its disk operation for real via
;;; CL-HOST-KIT. None of them needs to explicitly "refresh" TREE afterwards:
;;; FILE-TREE-ENTRIES (domain/file-tree.lisp's %FILE-TREE-FLATTEN) calls
;;; FILE-TREE-CHILD-LISTER fresh on every invocation rather than caching a
;;; previous listing, so the very next FILE-TREE-ENTRIES call -- e.g. the
;;; next frame's presentation/layout.lisp redraw -- already reflects whatever
;;; these methods just did to disk.

(defgeneric file-tree-create-file (tree path)
  (:documentation
   "Create a new, empty regular file on disk at PATH (via CL-HOST-KIT).
Signals an error if PATH already exists. Returns PATH.")
  (:method (tree path)
    (declare (ignorable tree))
    (host-kit:write-file-string "" path :if-exists :error)
    path))

(defgeneric file-tree-create-directory (tree path)
  (:documentation
   "Create a new, empty directory on disk at PATH (via CL-HOST-KIT). Signals
an error if PATH already exists. Returns PATH.")
  (:method (tree path)
    (declare (ignorable tree))
    (host-kit:create-directory path :if-exists :error)
    path))

(defgeneric file-tree-rename (tree old-path new-path)
  (:documentation
   "Move/rename the file or directory at OLD-PATH to NEW-PATH on disk (via
CL-HOST-KIT:MOVE-PATH). Signals an error if OLD-PATH does not exist or
NEW-PATH already does. Returns NEW-PATH.")
  (:method (tree old-path new-path)
    (declare (ignorable tree))
    (host-kit:move-path old-path new-path :if-exists :error)
    new-path))

(defgeneric file-tree-delete (tree path)
  (:documentation
   "Delete the file or directory at PATH from disk (via CL-HOST-KIT).
Signals an error if PATH does not exist. Returns TREE.")
  (:method (tree path)
    (host-kit:delete-path path :recursive t :if-does-not-exist :error)
    tree))

;;; ---------------------------------------------------------------------
;;; BUFFER-LOAD / BUFFER-SAVE: the real, disk-backed :METHOD bodies for the
;;; generics declared (name, docstring, argument list only) in
;;; domain/buffer.lisp. domain/buffer.lisp is deliberately pure text-storage
;;; state with no dependency on CL-HOST-KIT -- see that file's header
;;; comment -- so the actual file I/O lives here instead, same split as
;;; FILE-TREE-CREATE-FILE and friends above.
;;; ---------------------------------------------------------------------

(defmethod buffer-load (path)
  (let ((content (host-kit:read-file-string path)))
    (make-buffer :name (file-namestring path) :path path :initial-content content)))

(defmethod buffer-save (buffer)
  (let ((path (buffer-path buffer)))
    (unless path
      (error "buffer-save: buffer ~A has no associated path" (buffer-name buffer)))
    (host-kit:write-file-string (buffer-text buffer) path)
    (setf (%buffer-modified-p buffer) nil))
  buffer)
