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
        (signals error (file-tree-create-file nil path)))))

  (it
    "creates a file inside the file-tree root"
    (host-kit:with-temporary-directory (root)
      (let ((path (merge-pathnames "inside.txt" root))
            (tree (make-file-tree root)))
        (expect (file-tree-create-file tree path) :to-equal path)
        (expect (host-kit:read-file-string path) :to-equal ""))))

  (it
    "rejects creating a file outside the file-tree root"
    (host-kit:with-temporary-directory (outside)
      (host-kit:with-temporary-directory (root)
        (let ((path (merge-pathnames "outside.txt" outside))
              (tree (make-file-tree root)))
          (signals error (file-tree-create-file tree path))
          (expect (host-kit:path-exists-p path) :to-be-falsy)))))

  #+sbcl
  (it
    "creates a literal wildcard filename inside a literal wildcard directory"
    (host-kit:with-temporary-directory (root)
      (let* ((tree (make-file-tree root))
             (directory (merge-pathnames "literal*directory/" root))
             (path (merge-pathnames "literal*file.txt" directory))
             (native-path (sb-ext:parse-native-namestring (namestring path))))
        (file-tree-create-directory tree directory)
        (expect (file-tree-create-file tree path) :to-equal path)
        (expect (host-kit:read-file-string native-path) :to-equal "")
        (expect (loom/feature/file-tree::%file-tree-canonical-pathname native-path)
                :to-equal (truename native-path))
        (signals error (file-tree-create-file tree path))))))

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
        (signals error (file-tree-create-directory nil path)))))

  (it
    "creates a directory inside the file-tree root"
    (host-kit:with-temporary-directory (root)
      (let ((path (merge-pathnames "inside/" root))
            (tree (make-file-tree root)))
        (expect (file-tree-create-directory tree path) :to-equal path)
        (expect (host-kit:directory-exists-p path) :to-be-truthy))))

  (it
    "rejects creating a directory outside the file-tree root"
    (host-kit:with-temporary-directory (outside)
      (host-kit:with-temporary-directory (root)
        (let ((path (merge-pathnames "outside/" outside))
              (tree (make-file-tree root)))
          (signals error (file-tree-create-directory tree path))
          (expect (host-kit:path-exists-p path) :to-be-falsy)))))

  #+sbcl
  (it
    "rejects creating a literal wildcard directory outside the file-tree root"
    (host-kit:with-temporary-directory (outside)
      (host-kit:with-temporary-directory (root)
        (let* ((path (merge-pathnames "literal*directory/" outside))
               (native-path (sb-ext:parse-native-namestring (namestring path)))
               (tree (make-file-tree root)))
          (signals error (file-tree-create-directory tree path))
          (expect (host-kit:path-exists-p native-path) :to-be-falsy))))))
