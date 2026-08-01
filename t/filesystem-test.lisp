;;;; t/filesystem-test.lisp
;;;;
;;;; Infrastructure layer: the disk-touching file-tree generics
;;;; (FILE-TREE-CREATE-FILE, FILE-TREE-CREATE-DIRECTORY, FILE-TREE-RENAME,
;;;; FILE-TREE-DELETE) and LOOM-FS-LIST-DIRECTORY, exercised against a real
;;;; temporary directory on disk via CL-HOST-KIT:WITH-TEMPORARY-DIRECTORY
;;;; (created under the OS temp directory, cleaned up automatically after
;;;; each test).
;;;;
;;;; TREE is passed as NIL throughout: none of these methods currently do
;;;; anything with TREE (domain/file-tree.lisp has no child-lister seam yet
;;;; for them to refresh through -- see the TODOs in
;;;; infrastructure/filesystem.lisp), so any value satisfies the protocol's
;;;; TREE parameter for now.
(in-package #:loom/test)

(describe
  "file-tree-create-file"
  (it
    "creates an empty regular file and returns path"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "new-file.txt" dir)))
        (expect (file-tree-create-file nil path) :to-equal path)
        (expect (host-kit:path-exists-p path) :to-be-truthy)
        (expect (host-kit:read-file-string path) :to-equal ""))))

  (it
    "signals an error when path already exists"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "existing.txt" dir)))
        (host-kit:write-file-string "already here" path)
        (signals 'error (file-tree-create-file nil path))))))

(describe
  "file-tree-create-directory"
  (it
    "creates an empty directory and returns path"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "subdir/" dir)))
        (expect (file-tree-create-directory nil path) :to-equal path)
        (expect (host-kit:directory-exists-p path) :to-be-truthy))))

  (it
    "signals an error when path already exists"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "subdir/" dir)))
        (host-kit:create-directory path)
        (signals 'error (file-tree-create-directory nil path))))))

(describe
  "file-tree-rename"
  (it
    "moves a file on disk and returns new-path"
    (host-kit:with-temporary-directory (dir)
      (let ((old-path (merge-pathnames "old.txt" dir))
            (new-path (merge-pathnames "new.txt" dir)))
        (host-kit:write-file-string "contents" old-path)
        (expect (file-tree-rename nil old-path new-path) :to-equal new-path)
        (expect (host-kit:path-exists-p old-path) :to-be-falsy)
        (expect (host-kit:read-file-string new-path) :to-equal "contents")))))

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
    "signals an error when path does not exist"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "missing.txt" dir)))
        (signals 'error (file-tree-delete nil path))))))

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
                '("aardvark" "zoo" "apple.txt" "banana.txt"))))))
