(in-package #:loom/test)

(describe "loom concurrent runtime"
  (it "deduplicates paths while preserving requested order in the cache"
    (let* ((path-a "/root/a/")
           (path-b "/root/b/")
           (entries-a '(("/root/a/file" . :file)))
           (entries-b '(("/root/b/file" . :file)))
           (entries-by-path (list (cons path-a entries-a)
                                  (cons path-b entries-b))))
      (multiple-value-bind (lister call-count)
          (%make-counting-directory-lister entries-by-path)
        (let ((runtime
                (loom/feature/file-tree:make-loom-concurrent-runtime
                 :directory-lister lister)))
          (unwind-protect
               (progn
                 (expect
                  (loom/feature/file-tree::loom-concurrent-runtime-directory-lister runtime)
                  :to-be lister)
                 (%await-prefetch runtime (list path-b path-a path-b))
                 (loom/feature/file-tree:loom-concurrent-runtime-drain runtime)
                 (expect
                  (mapcar
                   (lambda (path)
                     (loom/feature/file-tree:loom-concurrent-runtime-directory-entries
                      runtime path))
                   (list path-b path-a path-b))
                  :to-equal (list entries-b entries-a entries-b))
                 (expect (funcall call-count path-a) :to-be 1)
                 (expect (funcall call-count path-b) :to-be 1)
                 (%await-prefetch runtime (list path-a path-b))
                 (loom/feature/file-tree:loom-concurrent-runtime-drain runtime)
                 (expect (funcall call-count path-a) :to-be 1)
                 (expect (funcall call-count path-b) :to-be 1))
            (ignore-errors
              (loom/feature/file-tree:loom-concurrent-runtime-shutdown runtime)))))))

  (it "deduplicates relative and absolute spellings of the same directory"
    (let* ((relative-path ".")
           (absolute-path (namestring (truename ".")))
           (call-count (cl-concurrent-kit:make-atomic-counter))
           (runtime
             (loom/feature/file-tree:make-loom-concurrent-runtime
              :directory-lister
              (lambda (path)
                (declare (ignore path))
                (cl-concurrent-kit:atomic-counter-incf call-count)
                nil))))
      (unwind-protect
           (multiple-value-bind (promises accepted)
               (loom/feature/file-tree:loom-concurrent-runtime-prefetch
                runtime
                (list relative-path absolute-path))
             (expect accepted :to-be 1)
             (dolist (promise promises)
               (cl-concurrent-kit:await
                promise
                :timeout (%concurrent-runtime-test-timeout)))
             (loom/feature/file-tree:loom-concurrent-runtime-drain runtime)
             (expect (cl-concurrent-kit:atomic-counter-value call-count)
                     :to-be 1))
        (ignore-errors
          (loom/feature/file-tree:loom-concurrent-runtime-shutdown runtime)))))

  (it "re-signals a worker error when a prefetch promise is awaited"
    (let ((runtime
            (loom/feature/file-tree:make-loom-concurrent-runtime
             :directory-lister
             (lambda (path)
               (error "broken directory lister: ~A" path)))))
      (unwind-protect
           (let ((condition nil))
             (handler-case
                 (%await-prefetch runtime (list "/broken/"))
               (error (caught-condition)
                 (setf condition caught-condition)))
             (expect condition :to-be-truthy)
             (expect (search "broken directory lister"
                             (princ-to-string condition))
                     :to-be-truthy)
             (loom/feature/file-tree:loom-concurrent-runtime-drain runtime)
             (multiple-value-bind (directory-error present-p)
                 (loom/feature/file-tree:loom-concurrent-runtime-directory-error
                  runtime
                  "/broken/")
               (expect present-p :to-be-truthy)
               (expect (search "broken directory lister"
                               (princ-to-string directory-error))
                       :to-be-truthy))
             (multiple-value-bind (promises accepted)
                 (loom/feature/file-tree:loom-concurrent-runtime-prefetch
                  runtime
                  (list "/broken/"))
               (declare (ignore promises))
               (expect accepted :to-be 0)))
        (ignore-errors
          (loom/feature/file-tree:loom-concurrent-runtime-shutdown runtime))))))
