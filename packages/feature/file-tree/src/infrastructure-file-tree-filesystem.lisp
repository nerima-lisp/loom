;;;; packages/feature/file-tree/src/infrastructure-file-tree-filesystem.lisp
;;;;
;;;; Infrastructure layer: the file-tree protocol's disk-touching mutation
;;;; generics, split out of the tree-state generics in domain/file-tree.lisp
;;;; because these operate on the real filesystem rather than on pure tree
;;;; state.
;;;;
;;;; Most of them reach the disk through *LOOM-FILESYSTEM*, a CL-BOUNDARY-KIT
;;;; filesystem boundary, so t/unit/filesystem-test.lisp can rebind that one
;;;; variable to an in-memory fake instead of creating a real temporary
;;;; directory. The SBCL-specific literal-namestring implementation lives in
;;;; infrastructure-filesystem-native.lisp, keeping this file focused on
;;;; mutation operations. FILE-TREE-DELETE deliberately stays on CL-HOST-KIT
;;;; directly, because routing it through the boundary would cost correctness
;;;; rather than buy testability:
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
    (%dispatch-native-path-operation
        (path)
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
    (%dispatch-native-path-operation
        (path)
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
    (%dispatch-native-path-operation
        (old-path new-path)
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
    (%dispatch-native-path-operation
        (path)
        (%native-delete-path path)
        ;; Not *LOOM-FILESYSTEM*: recursing over the boundary's list-directory
        ;; would follow symlinks out of the tree. See this file's header
        ;; comment.
        (host-kit:delete-path path :recursive t :if-does-not-exist :error))
    tree))
