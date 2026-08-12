(in-package #:loom/test)

(describe "loom concurrent runtime"
  (it "drops a stale pending task when priming an in-flight directory"
    (let* ((path "/root/primed/")
           (started (cl-concurrent-kit:make-channel :buffer-size 1))
           (release (cl-concurrent-kit:make-channel :buffer-size 1))
           (primed-entries '(("/root/primed/primed-file" . :file)))
           (runtime
             (loom/feature/file-tree:make-loom-concurrent-runtime
              :directory-lister
              (lambda (requested-path)
                (cl-concurrent-kit:send started requested-path)
                (cl-concurrent-kit:recv release)
                '(("/root/primed/stale-file" . :file))))))
      (unwind-protect
           (multiple-value-bind (promises accepted)
               (loom/feature/file-tree:loom-concurrent-runtime-prefetch runtime (list path))
             (expect accepted :to-be 1)
             (let ((promise (first promises)))
               (multiple-value-bind (started-path received-p)
                   (cl-concurrent-kit:recv
                    started
                    :timeout (%concurrent-runtime-test-timeout))
                 (expect started-path :to-equal path)
                 (expect received-p :to-be t))
               (loom/feature/file-tree:loom-concurrent-runtime-prime-directory
                runtime
                path
                primed-entries)
               (expect (hash-table-count
                        (loom/feature/file-tree::loom-concurrent-runtime-pending runtime))
                       :to-be 0)
               (expect (cl-concurrent-kit:try-send release :release)
                       :to-be-truthy)
               (cl-concurrent-kit:await
                promise
                :timeout (%concurrent-runtime-test-timeout))
               (loom/feature/file-tree:loom-concurrent-runtime-drain runtime)
               (expect
                (loom/feature/file-tree:loom-concurrent-runtime-directory-entries runtime path)
                :to-equal primed-entries)))
        (ignore-errors
          (cl-concurrent-kit:try-send release :cleanup))
        (ignore-errors
          (cl-concurrent-kit:close-channel started))
        (ignore-errors
          (cl-concurrent-kit:close-channel release))
        (ignore-errors
          (loom/feature/file-tree:loom-concurrent-runtime-shutdown runtime))))))
