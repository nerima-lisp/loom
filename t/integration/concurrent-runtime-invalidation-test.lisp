(in-package #:loom/test)

(describe "loom concurrent runtime"
  (it "accepts only results from the current generation"
    (let ((runtime (loom/feature/file-tree:make-loom-concurrent-runtime)))
      (unwind-protect
           (let ((key "directory")
                 (generation-table
                   (loom/feature/file-tree::loom-concurrent-runtime-generation
                    runtime)))
             (setf (gethash key generation-table) 2)
             (expect (loom/feature/file-tree::%directory-result-current-p
                      runtime key 2)
                     :to-be-truthy)
             (expect (loom/feature/file-tree::%directory-result-current-p
                      runtime key 1)
                     :to-be-falsy))
        (loom/feature/file-tree:loom-concurrent-runtime-shutdown runtime))))

  (it-each ((:entries) (:error) (:stale))
      "applies only current directory results (~A)" (kind)
    (let ((runtime (loom/feature/file-tree:make-loom-concurrent-runtime))
          (path "/root/results/"))
      (unwind-protect
           (let* ((key (loom/feature/file-tree::%directory-key path))
                  (entries '(("/root/results/file" . :file)))
                  (condition (make-condition 'simple-error
                                              :format-control "listing failed"))
                  (generation-table
                    (loom/feature/file-tree::loom-concurrent-runtime-generation
                     runtime)))
             (setf (gethash key generation-table) 2)
             (loom/feature/file-tree::%apply-directory-result
              runtime
              (case kind
                (:entries (list :kind :entries :key key :generation 2
                                :entries entries))
                (:error (list :kind :error :key key :generation 2
                              :condition condition))
                (:stale (list :kind :entries :key key :generation 1
                              :entries entries))))
             (case kind
               (:entries
                (expect (loom/feature/file-tree:loom-concurrent-runtime-directory-entries
                         runtime path)
                        :to-equal entries)
                (expect (loom/feature/file-tree:loom-concurrent-runtime-directory-error
                         runtime path)
                        :to-be nil))
               (:error
                (expect (loom/feature/file-tree:loom-concurrent-runtime-directory-entries
                         runtime path)
                        :to-be nil)
                (expect (loom/feature/file-tree:loom-concurrent-runtime-directory-error
                         runtime path)
                        :to-be condition))
               (:stale
                (multiple-value-bind (value present-p)
                    (loom/feature/file-tree:loom-concurrent-runtime-directory-entries
                     runtime path)
                  (declare (ignore value))
                  (expect present-p :to-be nil)))))
        (loom/feature/file-tree:loom-concurrent-runtime-shutdown runtime))))

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
