;;;; t/unit/filesystem-create-test.lisp
;;;;
;;;; FILE-TREE-CREATE-FILE and FILE-TREE-CREATE-DIRECTORY boundary tests.
(in-package #:loom/test)

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
      (%with-fake-paths ((path "existing.txt"))
        (%with-fake-files ((path "already here"))
          (signals error (file-tree-create-file nil path))))))

  (it
    "leaves an existing file's contents intact when it refuses to overwrite"
    (with-fake-filesystem
      (%with-fake-paths ((path "existing.txt"))
        (%with-fake-files ((path "already here"))
          (signals error (file-tree-create-file nil path))
          (expect (%fake-read path) :to-equal "already here")))))

  (it
    "creates the file on the real filesystem and refuses to clobber one"
    (host-kit:with-temporary-directory (dir)
      (%with-real-paths (dir (path "new-file.txt"))
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
                 loom/feature/file-tree::*loom-filesystem* path)
                :to-be-truthy))))

  (it
    "signals an error when path already exists"
    (with-fake-filesystem
      (let ((path (%fake-path "subdir/")))
        (file-tree-create-directory nil path)
        (signals error (file-tree-create-directory nil path)))))

  (it
    "signals an error when path already exists on the real filesystem"
    (host-kit:with-temporary-directory (dir)
      (%with-real-paths (dir (path "subdir/"))
        (expect (file-tree-create-directory nil path) :to-equal path)
        (expect (host-kit:directory-exists-p path) :to-be-truthy)
        (signals error (file-tree-create-directory nil path))))))
