;;;; t/unit/filesystem-delete-test.lisp
;;;;
;;;; Delete tests against the native filesystem.
(in-package #:loom/test)

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
