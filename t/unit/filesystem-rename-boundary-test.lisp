;;;; t/unit/filesystem-rename-boundary-test.lisp
;;;;
;;;; Rename and buffer filesystem boundary tests.
(in-package #:loom/test)

(describe
  "file-tree-rename"
  (it
    "moves a file and returns new-path"
    (with-fake-filesystem
      (%with-fake-paths ((old-path "old.txt")
                         (new-path "new.txt"))
        (%with-fake-files ((old-path "contents"))
          (expect (file-tree-rename nil old-path new-path) :to-equal new-path)
          (expect (%fake-exists-p old-path) :to-be-falsy)
          (expect (%fake-read new-path) :to-equal "contents")))))

  (it
    "signals an error when old-path does not exist"
    (with-fake-filesystem
      (signals error
        (file-tree-rename nil (%fake-path "missing.txt") (%fake-path "new.txt")))))

  (it
    "signals an error when new-path already exists, without clobbering it"
    (with-fake-filesystem
      (%with-fake-paths ((old-path "old.txt")
                         (new-path "new.txt"))
        (%with-fake-files ((old-path "source contents")
                           (new-path "destination contents"))
          (signals error (file-tree-rename nil old-path new-path))
          (expect (%fake-read new-path) :to-equal "destination contents")
          (expect (%fake-read old-path) :to-equal "source contents")))))

  (it
    "moves a file on the real filesystem and returns new-path"
    (host-kit:with-temporary-directory (dir)
      (%with-real-paths (dir (old-path "old.txt")
                             (new-path "new.txt"))
        (%with-real-files ((old-path "contents"))
          (expect (file-tree-rename nil old-path new-path) :to-equal new-path)
          (expect (host-kit:path-exists-p old-path) :to-be-falsy)
          (expect (host-kit:read-file-string new-path) :to-equal "contents")))))

  (it
    "refuses to clobber an existing destination on the real filesystem"
    (host-kit:with-temporary-directory (dir)
      (%with-real-paths (dir (old-path "old.txt")
                             (new-path "new.txt"))
        (%with-real-files ((old-path "source contents")
                           (new-path "destination contents"))
          (signals error (file-tree-rename nil old-path new-path))
          (expect (host-kit:read-file-string new-path) :to-equal "destination contents")
          (expect (host-kit:read-file-string old-path) :to-equal "source contents")))))

  (it
    "signals an error when old-path does not exist on the real filesystem"
    (host-kit:with-temporary-directory (dir)
      (signals error
        (file-tree-rename nil
                          (merge-pathnames "missing.txt" dir)
                          (merge-pathnames "new.txt" dir))))))

(describe
  "buffer-load / buffer-save through the filesystem boundary"
  (it
    "loads a file's contents from the bound filesystem"
    (with-fake-filesystem
      (%with-fake-paths ((path "notes.txt"))
        (%with-fake-files ((path (format nil "line one~%line two")))
          (let ((buffer (buffer-load path)))
            (expect (buffer-name buffer) :to-equal "notes.txt")
            (expect (buffer-path buffer) :to-equal path)
            (expect (buffer-line-count buffer) :to-equal 2)
            (expect (buffer-line buffer 0) :to-equal "line one")
            (expect (buffer-modified-p buffer) :to-be-falsy))))))

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

  (it
    "writes nothing to the real disk while a fake filesystem is bound"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "should-not-appear.txt" dir)))
        (with-fake-filesystem
          (let ((buffer (make-buffer :path path :initial-content "in memory only")))
            (buffer-save buffer)
            (expect (%fake-read path) :to-equal "in memory only")))
        (expect (host-kit:path-exists-p path) :to-be-falsy)))))
