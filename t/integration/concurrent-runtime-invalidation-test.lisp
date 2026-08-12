(in-package #:loom/test)

(describe "loom concurrent runtime"
  (it "primes and invalidates a path together with its parent"
    (let ((runtime
            (loom/feature/file-tree:make-loom-concurrent-runtime
             :directory-lister
             (lambda (path)
               (declare (ignore path))
               nil))))
      (unwind-protect
           (let ((parent "/root/child/")
                 (path "/root/child/file.txt")
                 (parent-entries '(("/root/child/file.txt" . :file)))
                 (path-entries '(("/root/child/file.txt/child" . :file))))
             (expect
              (loom/feature/file-tree:loom-concurrent-runtime-prime-directory
               runtime
               parent
               parent-entries)
              :to-be parent-entries)
             (expect
              (loom/feature/file-tree:loom-concurrent-runtime-prime-directory
               runtime
               path
               path-entries)
              :to-be path-entries)
             (multiple-value-bind (entries present-p)
                 (loom/feature/file-tree:loom-concurrent-runtime-directory-entries
                  runtime
                  parent)
               (expect entries :to-be parent-entries)
               (expect present-p :to-be-truthy))
             (multiple-value-bind (entries present-p)
                 (loom/feature/file-tree:loom-concurrent-runtime-directory-entries
                  runtime
                  path)
               (expect entries :to-be path-entries)
               (expect present-p :to-be-truthy))
             (loom/feature/file-tree:loom-concurrent-runtime-invalidate-path runtime path)
             (multiple-value-bind (entries present-p)
                 (loom/feature/file-tree:loom-concurrent-runtime-directory-entries
                  runtime
                  parent)
               (declare (ignore entries))
               (expect present-p :to-be nil))
             (multiple-value-bind (entries present-p)
                 (loom/feature/file-tree:loom-concurrent-runtime-directory-entries
                  runtime
                  path)
               (declare (ignore entries))
               (expect present-p :to-be nil)))
        (ignore-errors
          (loom/feature/file-tree:loom-concurrent-runtime-shutdown runtime)))))

  (it "invalidates a directory only once when its parent is itself"
    (let ((runtime
            (loom/feature/file-tree:make-loom-concurrent-runtime
             :directory-lister
             (lambda (path)
               (declare (ignore path))
               nil))))
      (unwind-protect
           (let* ((path "/root/child/")
                  (key (loom/feature/file-tree::%directory-key path))
                  (entries '(("/root/child/file.txt" . :file)))
                  (generation-table
                    (loom/feature/file-tree::loom-concurrent-runtime-generation runtime)))
             (loom/feature/file-tree:loom-concurrent-runtime-prime-directory
              runtime
              path
              entries)
             (let ((generation-before (gethash key generation-table 0)))
               (loom/feature/file-tree:loom-concurrent-runtime-invalidate-path runtime path)
               (multiple-value-bind (cached present-p)
                   (loom/feature/file-tree:loom-concurrent-runtime-directory-entries
                    runtime
                    path)
                 (declare (ignore cached))
                 (expect present-p :to-be nil))
               (expect (gethash key generation-table)
                       :to-be
                       (1+ generation-before))))
        (ignore-errors
          (loom/feature/file-tree:loom-concurrent-runtime-shutdown runtime))))))
