;;;; t/unit/filesystem-listing-test.lisp
;;;;
;;;; Directory listing and pathname round-trip tests.
(in-package #:loom/test)

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
                '("real.txt")))))

  (it
    "round-trips literal namestrings with spaces, brackets, hashes, and Unicode"
    (host-kit:with-temporary-directory (dir)
      (let* ((old-name "space [bracket] # 日本語.txt")
             (new-name "renamed [bracket] # 日本語.txt")
             (conflict-name "conflict [bracket] # 日本語.txt")
             (old-path
               (pathname (format nil "~A~A" (namestring dir) old-name)))
             (new-path
               (pathname (format nil "~A~A" (namestring dir) new-name)))
             (conflict-path
               (pathname (format nil "~A~A" (namestring dir) conflict-name))))
        (expect (file-tree-create-file nil old-path) :to-equal old-path)
        (signals error (file-tree-create-file nil old-path))
        (let ((buffer (make-buffer :path old-path :initial-content "日本語の内容")))
          (buffer-save buffer)
          (expect (buffer-text (buffer-load old-path))
                  :to-equal
                  "日本語の内容"))
        (let ((entries (loom-fs-list-directory dir)))
          (expect (mapcar (lambda (entry) (file-namestring (car entry))) entries)
                  :to-equal
                  (list old-name))
          (expect (cdr (first entries)) :to-be :file)
          (expect (namestring (car (first entries)))
                  :to-equal
                  (namestring old-path)))
        (expect (file-tree-create-file nil conflict-path) :to-equal conflict-path)
        (let ((buffer
                (make-buffer :path conflict-path :initial-content "destination")))
          (buffer-save buffer))
        (signals error (file-tree-rename nil old-path conflict-path))
        (expect (buffer-text (buffer-load old-path))
                :to-equal
                "日本語の内容")
        (expect (buffer-text (buffer-load conflict-path))
                :to-equal
                "destination")
        (expect (file-tree-rename nil old-path new-path) :to-equal new-path)
        (expect (buffer-text (buffer-load new-path))
                :to-equal
                "日本語の内容")
        (file-tree-delete nil new-path)
        (signals error (file-tree-delete nil new-path))
        (signals error (file-tree-rename nil new-path old-path))
        (file-tree-delete nil conflict-path)
        (expect (loom-fs-list-directory dir) :to-be nil)
        (let* ((directory-name "folder [bracket] # 日本語")
               (directory-path
                 (pathname (format nil "~A~A/" (namestring dir) directory-name)))
               (nested-directory-name "nested folder [bracket] # 日本語")
               (nested-directory-path
                 (pathname (format nil "~A~A/"
                                   (namestring directory-path)
                                   nested-directory-name)))
               (nested-name "nested [bracket] # 日本語.txt")
               (nested-path
                 (pathname (format nil "~A~A"
                                   (namestring nested-directory-path)
                                   nested-name))))
          (expect (file-tree-create-directory nil nested-directory-path)
                  :to-equal nested-directory-path)
          (signals error (file-tree-create-directory nil nested-directory-path))
          (expect (mapcar #'cdr (loom-fs-list-directory directory-path))
                  :to-equal
                  '(:directory))
          (expect (file-tree-create-file nil nested-path)
                  :to-equal nested-path)
          (signals error (file-tree-create-file nil nested-path))
          (expect (mapcar (lambda (entry) (file-namestring (car entry)))
                          (loom-fs-list-directory nested-directory-path))
                  :to-equal
                  (list nested-name))
          (host-kit:with-temporary-directory (outside)
            (let* ((preserved (merge-pathnames "preserved.txt" outside))
                   (link-name "link [bracket] # 日本語")
                   (link-path
                     (pathname (format nil "~A~A"
                                       (namestring directory-path)
                                       link-name))))
              (host-kit:write-file-string "keep me" preserved)
              (sb-posix:symlink (namestring outside) (namestring link-path))
              (file-tree-delete nil directory-path)
              (expect (loom-fs-list-directory dir) :to-be nil)
              (expect (host-kit:path-exists-p preserved) :to-be-truthy)
              (expect (host-kit:read-file-string preserved) :to-equal "keep me")
              (signals error (file-tree-delete nil directory-path)))))))))
