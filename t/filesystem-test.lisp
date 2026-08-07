;;;; t/filesystem-test.lisp
;;;;
;;;; Infrastructure layer: the disk-touching file-tree generics
;;;; (FILE-TREE-CREATE-FILE, FILE-TREE-CREATE-DIRECTORY, FILE-TREE-RENAME,
;;;; FILE-TREE-DELETE), LOOM-FS-LIST-DIRECTORY, and the BUFFER-LOAD /
;;;; BUFFER-SAVE boundary seam.
;;;;
;;;; Two fixtures, deliberately:
;;;;
;;;;   The fake -- LOOM::*LOOM-FILESYSTEM* rebound to
;;;;   CL-BOUNDARY-KIT:MAKE-TEST-FILESYSTEM's in-memory filesystem. Fast, and
;;;;   it is what proves the boundary seam is real: if an operation still
;;;;   reached the disk directly, rebinding the variable would not redirect it
;;;;   and the assertions here would fail.
;;;;
;;;;   A real temporary directory -- CL-HOST-KIT:WITH-TEMPORARY-DIRECTORY,
;;;;   cleaned up automatically. Kept for at least one round trip per generic,
;;;;   because the fake and the real backend genuinely disagree in places: the
;;;;   real CL-BOUNDARY-KIT:FILESYSTEM-DIRECTORY-EXISTS-P answers T for a
;;;;   regular file (it probes PATH with a separator appended) where the fake
;;;;   answers NIL, and the real FILESYSTEM-PATH-EXISTS-P sees directories
;;;;   where the fake does not. The error contracts below exist to compensate
;;;;   for what the *real* backend does not enforce, so they are asserted
;;;;   against the real backend and not only against the fake.
;;;;
;;;; FILE-TREE-DELETE and LOOM-FS-LIST-DIRECTORY stay entirely on the real
;;;; fixture: both are implemented against CL-HOST-KIT rather than the
;;;; boundary (see src/infrastructure/filesystem.lisp's header comment for
;;;; why), so a fake would exercise nothing they actually use.
;;;;
;;;; TREE is passed as NIL throughout: none of the four disk-touching
;;;; generics exercised here (FILE-TREE-CREATE-FILE and friends) reads TREE
;;;; itself -- each operates on PATH alone and lets FILE-TREE-ENTRIES
;;;; (domain/file-tree.lisp) pick up the on-disk change on its next call via
;;;; the FILE-TREE-CHILD-LISTER seam -- so any value satisfies the protocol's
;;;; TREE parameter here.
(in-package #:loom/test)

(defun %fake-path (name)
  "Return NAME under the in-memory fake's root.
The fake keys its entries by pathname, so every reference to one file has to
merge against the same root to land on the same entry."
  (merge-pathnames name #P"/loom-fake/"))

(defmacro with-fake-filesystem (&body body)
  "Run BODY with LOOM::*LOOM-FILESYSTEM* bound to a fresh in-memory filesystem."
  `(let ((loom::*loom-filesystem* (cl-boundary-kit:make-test-filesystem)))
     ,@body))

(defun %fake-exists-p (path)
  (cl-boundary-kit:filesystem-path-exists-p loom::*loom-filesystem* path))

(defun %fake-read (path)
  (cl-boundary-kit:filesystem-read-file loom::*loom-filesystem* path))

(defun %fake-write (path content)
  (cl-boundary-kit:filesystem-store-file loom::*loom-filesystem* path content))

(describe
  "file-tree-create-file"
  (it
    "creates an empty regular file and returns path"
    (with-fake-filesystem
      (let ((path (%fake-path "new-file.txt")))
        (expect (file-tree-create-file nil path) :to-equal path)
        (expect (%fake-exists-p path) :to-be-truthy)
        (expect (%fake-read path) :to-equal ""))))

  (it
    "signals an error when path already exists"
    (with-fake-filesystem
      (let ((path (%fake-path "existing.txt")))
        (%fake-write path "already here")
        (signals error (file-tree-create-file nil path)))))

  (it
    "leaves an existing file's contents intact when it refuses to overwrite"
    (with-fake-filesystem
      (let ((path (%fake-path "existing.txt")))
        (%fake-write path "already here")
        (signals error (file-tree-create-file nil path))
        (expect (%fake-read path) :to-equal "already here"))))

  (it
    "creates the file on the real filesystem and refuses to clobber one"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "new-file.txt" dir)))
        (expect (file-tree-create-file nil path) :to-equal path)
        (expect (host-kit:read-file-string path) :to-equal "")
        (signals error (file-tree-create-file nil path))))))

(describe
  "file-tree-create-directory"
  (it
    "creates an empty directory and returns path"
    (with-fake-filesystem
      (let ((path (%fake-path "subdir/")))
        (expect (file-tree-create-directory nil path) :to-equal path)
        (expect (cl-boundary-kit:filesystem-directory-exists-p
                 loom::*loom-filesystem* path)
                :to-be-truthy))))

  ;; The guarded contract: CL-BOUNDARY-KIT:FILESYSTEM-MAKE-DIRECTORY is
  ;; ENSURE-DIRECTORIES-EXIST underneath and succeeds silently on an existing
  ;; directory, on both the real backend and the fake. Without
  ;; FILE-TREE-CREATE-DIRECTORY's own pre-check neither of these would signal.
  (it
    "signals an error when path already exists"
    (with-fake-filesystem
      (let ((path (%fake-path "subdir/")))
        (file-tree-create-directory nil path)
        (signals error (file-tree-create-directory nil path)))))

  (it
    "signals an error when path already exists on the real filesystem"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "subdir/" dir)))
        (expect (file-tree-create-directory nil path) :to-equal path)
        (expect (host-kit:directory-exists-p path) :to-be-truthy)
        (signals error (file-tree-create-directory nil path))))))

(describe
  "file-tree-rename"
  (it
    "moves a file and returns new-path"
    (with-fake-filesystem
      (let ((old-path (%fake-path "old.txt"))
            (new-path (%fake-path "new.txt")))
        (%fake-write old-path "contents")
        (expect (file-tree-rename nil old-path new-path) :to-equal new-path)
        (expect (%fake-exists-p old-path) :to-be-falsy)
        (expect (%fake-read new-path) :to-equal "contents"))))

  (it
    "signals an error when old-path does not exist"
    (with-fake-filesystem
      (signals error
        (file-tree-rename nil (%fake-path "missing.txt") (%fake-path "new.txt")))))

  ;; The guarded contract, and the reason it is guarded: CL:RENAME-FILE --
  ;; which CL-BOUNDARY-KIT:FILESYSTEM-RENAME-FILE calls -- silently replaces an
  ;; existing destination on SBCL, and the fake's rename overwrites its entry
  ;; just as silently. Asserting that NEW-PATH still holds its own contents is
  ;; what makes this test fail if FILE-TREE-RENAME's pre-check is removed.
  (it
    "signals an error when new-path already exists, without clobbering it"
    (with-fake-filesystem
      (let ((old-path (%fake-path "old.txt"))
            (new-path (%fake-path "new.txt")))
        (%fake-write old-path "source contents")
        (%fake-write new-path "destination contents")
        (signals error (file-tree-rename nil old-path new-path))
        (expect (%fake-read new-path) :to-equal "destination contents")
        (expect (%fake-read old-path) :to-equal "source contents"))))

  (it
    "moves a file on the real filesystem and returns new-path"
    (host-kit:with-temporary-directory (dir)
      (let ((old-path (merge-pathnames "old.txt" dir))
            (new-path (merge-pathnames "new.txt" dir)))
        (host-kit:write-file-string "contents" old-path)
        (expect (file-tree-rename nil old-path new-path) :to-equal new-path)
        (expect (host-kit:path-exists-p old-path) :to-be-falsy)
        (expect (host-kit:read-file-string new-path) :to-equal "contents"))))

  (it
    "refuses to clobber an existing destination on the real filesystem"
    (host-kit:with-temporary-directory (dir)
      (let ((old-path (merge-pathnames "old.txt" dir))
            (new-path (merge-pathnames "new.txt" dir)))
        (host-kit:write-file-string "source contents" old-path)
        (host-kit:write-file-string "destination contents" new-path)
        (signals error (file-tree-rename nil old-path new-path))
        (expect (host-kit:read-file-string new-path) :to-equal "destination contents")
        (expect (host-kit:read-file-string old-path) :to-equal "source contents"))))

  (it
    "signals an error when old-path does not exist on the real filesystem"
    (host-kit:with-temporary-directory (dir)
      (signals error
        (file-tree-rename nil
                          (merge-pathnames "missing.txt" dir)
                          (merge-pathnames "new.txt" dir))))))

;;; FILE-TREE-DELETE is the one file-tree generic still implemented against
;;; CL-HOST-KIT rather than the boundary, so every test here is real-disk.
(describe
  "file-tree-delete"
  (it
    "deletes a regular file from disk and returns tree"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "gone.txt" dir))
            (tree (list :a-tree-placeholder)))
        (host-kit:write-file-string "x" path)
        (expect (file-tree-delete tree path) :to-be tree)
        (expect (host-kit:path-exists-p path) :to-be-falsy))))

  (it
    "deletes a non-empty directory from disk"
    (host-kit:with-temporary-directory (dir)
      (let ((subdir (merge-pathnames "subdir/" dir)))
        (host-kit:create-directory subdir)
        (host-kit:write-file-string "x" (merge-pathnames "inner.txt" subdir))
        (file-tree-delete nil subdir)
        (expect (host-kit:path-exists-p subdir) :to-be-falsy))))

  (it
    "deletes a directory tree several levels deep"
    (host-kit:with-temporary-directory (dir)
      (let ((subdir (merge-pathnames "subdir/" dir))
            (nested (merge-pathnames "subdir/nested/" dir)))
        (host-kit:create-directory subdir)
        (host-kit:create-directory nested)
        (host-kit:write-file-string "x" (merge-pathnames "top.txt" subdir))
        (host-kit:write-file-string "y" (merge-pathnames "deep.txt" nested))
        (file-tree-delete nil subdir)
        (expect (host-kit:path-exists-p subdir) :to-be-falsy))))

  ;; Regression guard for why FILE-TREE-DELETE is NOT built on the boundary's
  ;; FILESYSTEM-LIST-DIRECTORY: that function is CL:DIRECTORY underneath, which
  ;; resolves symlinks, so recursing over its results deletes the contents of
  ;; whatever a symlink points at. The sidebar's delete command has no
  ;; confirmation prompt, so following a link out of the tree would destroy
  ;; unrelated files.
  (it
    "does not follow a symlink out of the tree when deleting a directory"
    (host-kit:with-temporary-directory (outside)
      (host-kit:with-temporary-directory (dir)
        (let ((preserved (merge-pathnames "preserved.txt" outside))
              (subdir (merge-pathnames "subdir/" dir)))
          (host-kit:write-file-string "keep me" preserved)
          (host-kit:create-directory subdir)
          (sb-posix:symlink (namestring outside)
                            (namestring (merge-pathnames "link" subdir)))
          (file-tree-delete nil subdir)
          (expect (host-kit:path-exists-p subdir) :to-be-falsy)
          (expect (host-kit:path-exists-p preserved) :to-be-truthy)
          (expect (host-kit:read-file-string preserved) :to-equal "keep me")))))

  (it
    "signals an error when path does not exist"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "missing.txt" dir)))
        (signals error (file-tree-delete nil path))))))

;;; BUFFER-LOAD / BUFFER-SAVE against the boundary. t/buffer-test.lisp already
;;; round-trips both through a real temporary directory; what is asserted here
;;; is the part that only the seam can show -- that rebinding
;;; LOOM::*LOOM-FILESYSTEM* actually redirects the I/O, so neither method holds
;;; a hidden direct path to the disk.
(describe
  "buffer-load / buffer-save through the filesystem boundary"
  (it
    "loads a file's contents from the bound filesystem"
    (with-fake-filesystem
      (let ((path (%fake-path "notes.txt")))
        (%fake-write path (format nil "line one~%line two"))
        (let ((buffer (buffer-load path)))
          (expect (buffer-name buffer) :to-equal "notes.txt")
          (expect (buffer-path buffer) :to-equal path)
          (expect (buffer-line-count buffer) :to-equal 2)
          (expect (buffer-line buffer 0) :to-equal "line one")
          (expect (buffer-modified-p buffer) :to-be-falsy)))))

  (it
    "saves buffer-text into the bound filesystem and clears modified-p"
    (with-fake-filesystem
      (let* ((path (%fake-path "out.txt"))
             (buffer (make-buffer :path path :initial-content "hi")))
        (buffer-set-point buffer 0 2)
        (buffer-insert-string buffer " there")
        (expect (buffer-modified-p buffer) :to-be-truthy)
        (buffer-save buffer)
        (expect (buffer-modified-p buffer) :to-be-falsy)
        (expect (%fake-read path) :to-equal "hi there"))))

  ;; Non-vacuity check for the whole refactor: the buffer's path names a
  ;; location in a real temporary directory, but the bound filesystem is the
  ;; in-memory fake, so nothing may appear on disk.
  (it
    "writes nothing to the real disk while a fake filesystem is bound"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "should-not-appear.txt" dir)))
        (with-fake-filesystem
          (let ((buffer (make-buffer :path path :initial-content "in memory only")))
            (buffer-save buffer)
            (expect (%fake-read path) :to-equal "in memory only")))
        (expect (host-kit:path-exists-p path) :to-be-falsy)))))

(describe
  "loom-fs-list-directory"
  (it
    "lists directories before files, alphabetically within each group"
    (host-kit:with-temporary-directory (dir)
      (host-kit:write-file-string "" (merge-pathnames "banana.txt" dir))
      (host-kit:write-file-string "" (merge-pathnames "apple.txt" dir))
      (host-kit:create-directory (merge-pathnames "zoo/" dir))
      (host-kit:create-directory (merge-pathnames "aardvark/" dir))
      (let ((entries (loom-fs-list-directory dir)))
        (expect (mapcar #'cdr entries)
                :to-equal
                '(:directory :directory :file :file))
        (expect (mapcar (lambda (entry) (file-namestring (car entry))) entries)
                :to-equal
                '("aardvark" "zoo" "apple.txt" "banana.txt")))))

  (it
    "omits special entries that are neither a regular file nor a directory"
    (host-kit:with-temporary-directory (dir)
      (host-kit:write-file-string "" (merge-pathnames "real.txt" dir))
      (sb-posix:symlink "real.txt" (merge-pathnames "a-symlink" dir))
      (let ((entries (loom-fs-list-directory dir)))
        (expect (mapcar (lambda (entry) (file-namestring (car entry))) entries)
                :to-equal
                '("real.txt"))))))
