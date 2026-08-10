;;;; packages/feature/file-tree/src/infrastructure-filesystem.lisp
;;;;
;;;; Infrastructure layer: the file-tree protocol's disk-touching generics,
;;;; split out of the tree-state generics in domain/file-tree.lisp because
;;;; these operate on the real filesystem rather than on pure tree state.
;;;;
;;;; Most of them reach the disk through *LOOM-FILESYSTEM*, a CL-BOUNDARY-KIT
;;;; filesystem boundary, so t/unit/filesystem-test.lisp can rebind that one
;;;; variable to an in-memory fake instead of creating a real temporary
;;;; directory. The SBCL-specific literal-namestring implementation lives in
;;;; infrastructure-filesystem-native.lisp, keeping this file focused on
;;;; directory listing and file-tree/buffer operations. Two operations
;;;; deliberately stay on CL-HOST-KIT directly, because routing them through
;;;; the boundary would cost correctness rather than buy testability:
;;;;
;;;;   LOOM-FS-LIST-DIRECTORY needs each entry classified as :DIRECTORY or
;;;;   :FILE. CL-BOUNDARY-KIT:FILESYSTEM-LIST-DIRECTORY returns bare
;;;;   pathnames with no classification, so the kind would have to be
;;;;   recovered with a second probe per entry, whereas
;;;;   CL-HOST-KIT:CALL-WITH-DIRECTORY-ENTRIES already reports it in one pass.
;;;;
;;;;   FILE-TREE-DELETE deletes a populated directory tree. The boundary's
;;;;   FILESYSTEM-DELETE-DIRECTORY removes only an already-empty directory, so
;;;;   the recursion would have to be written here on top of
;;;;   FILESYSTEM-LIST-DIRECTORY -- which is CL:DIRECTORY underneath and so
;;;;   RESOLVES SYMLINKS. Recursing over resolved entries walks *through* a
;;;;   symlink to a directory outside the tree and deletes its contents; the
;;;;   file-tree sidebar's delete command has no confirmation prompt, so that
;;;;   is unacceptable. CL-HOST-KIT:DELETE-PATH :RECURSIVE T does not follow
;;;;   symlinks and does the whole job in one call.
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

;;; Each of the four generics below performs its disk operation for real --
;;; ordinary pathnames through *LOOM-FILESYSTEM*, literal namestring
;;; pathnames through the native adapter above, and FILE-TREE-DELETE through
;;; CL-HOST-KIT except for that same native adapter case. None of them needs
;;; to explicitly "refresh" TREE afterwards:
;;; FILE-TREE-ENTRIES (domain/file-tree.lisp's %FILE-TREE-FLATTEN) calls
;;; FILE-TREE-CHILD-LISTER fresh on every invocation rather than caching a
;;; previous listing, so the very next FILE-TREE-ENTRIES call -- e.g. the
;;; next frame's presentation/layout.lisp redraw -- already reflects whatever
;;; these methods just did to disk.

(defgeneric file-tree-create-file (tree path)
  (:documentation
   "Create a new, empty regular file on disk at PATH (via *LOOM-FILESYSTEM*).
Signals an error if PATH already exists. Returns PATH.")
  (:method (tree path)
    (declare (ignorable tree))
    (if (%native-path-operation-p path)
        (%native-create-file path)
        (cl-boundary-kit:filesystem-store-file *loom-filesystem* path ""
                                               :if-exists :error))
    path))

(defgeneric file-tree-create-directory (tree path)
  (:documentation
   "Create a new, empty directory on disk at PATH (via *LOOM-FILESYSTEM*). Signals
an error if PATH already exists. Returns PATH.")
  (:method (tree path)
    (declare (ignorable tree))
    (if (%native-path-operation-p path)
        (progn
          (when (%native-path-exists-p path)
            (error "file-tree-create-directory: ~A already exists" path))
          (%native-make-directory path))
        (progn
          ;; CL-BOUNDARY-KIT:FILESYSTEM-MAKE-DIRECTORY is ENSURE-DIRECTORIES-EXIST
          ;; underneath, so it succeeds silently on an already-existing
          ;; directory rather than signalling. The "already exists" half of
          ;; this generic's contract therefore has to be checked here.
          (when (cl-boundary-kit:filesystem-directory-exists-p
                  *loom-filesystem* path)
            (error "file-tree-create-directory: ~A already exists" path))
          (cl-boundary-kit:filesystem-make-directory *loom-filesystem* path)))
    path))

(defgeneric file-tree-rename (tree old-path new-path)
  (:documentation
   "Move/rename the file or directory at OLD-PATH to NEW-PATH on disk (via
*LOOM-FILESYSTEM*). Signals an error if OLD-PATH does not exist or
NEW-PATH already does. Returns NEW-PATH.")
  (:method (tree old-path new-path)
    (declare (ignorable tree))
    (if (%native-path-operation-p old-path new-path)
        (progn
          (unless (%native-path-exists-p old-path)
            (error "file-tree-rename: ~A does not exist" old-path))
          (when (%native-path-exists-p new-path)
            (error "file-tree-rename: ~A already exists" new-path))
          (%native-rename old-path new-path))
        (progn
          ;; Both halves of the contract are checked here rather than
          ;; delegated: CL-BOUNDARY-KIT:FILESYSTEM-RENAME-FILE is
          ;; CL:RENAME-FILE underneath, which on SBCL silently overwrites an
          ;; existing destination instead of signalling.
          (unless (cl-boundary-kit:filesystem-path-exists-p
                    *loom-filesystem* old-path)
            (error "file-tree-rename: ~A does not exist" old-path))
          (when (cl-boundary-kit:filesystem-path-exists-p
                  *loom-filesystem* new-path)
            (error "file-tree-rename: ~A already exists" new-path))
          (cl-boundary-kit:filesystem-rename-file
           *loom-filesystem* old-path new-path)))
    new-path))

(defgeneric file-tree-delete (tree path)
  (:documentation
   "Delete the file or directory at PATH from disk (via CL-HOST-KIT).
Signals an error if PATH does not exist. Returns TREE.")
  (:method (tree path)
    (if (%native-path-operation-p path)
        (%native-delete-path path)
        (progn
          ;; Not *LOOM-FILESYSTEM*: recursing over the boundary's list-directory
          ;; would follow symlinks out of the tree. See this file's header
          ;; comment.
          (host-kit:delete-path path :recursive t :if-does-not-exist :error)))
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
  (let ((content (if (%native-path-operation-p path)
                     (%native-read-file path)
                     (cl-boundary-kit:filesystem-read-file
                      *loom-filesystem* path))))
    (let ((buffer (make-buffer :name (file-namestring path)
                               :path path
                               :initial-content content)))
      (buffer-set-major-mode buffer
                             (loom/feature/mode:major-mode-for-path path))
      (when (and (eq *loom-filesystem* *loom-real-filesystem*)
                 (not (if (%native-path-operation-p path)
                          (%native-file-writable-p path)
                          (host-kit:file-writable-p path))))
        (buffer-set-read-only buffer t))
      buffer)))

(defmethod buffer-save (buffer)
  (let ((path (buffer-path buffer)))
    (unless path
      (error "buffer-save: buffer ~A has no associated path" (buffer-name buffer)))
    (when (buffer-read-only-p buffer)
      (error 'loom:buffer-read-only-error :buffer buffer))
    (run-before-save-hooks buffer)
    (if (%native-path-operation-p path)
        (%native-write-file path (buffer-text buffer))
        (cl-boundary-kit:filesystem-store-file
         *loom-filesystem* path (buffer-text buffer)))
    (buffer-mark-saved buffer)
    (run-after-save-hooks buffer))
  buffer)
