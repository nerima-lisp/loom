(in-package #:loom/test)

(describe "loom concurrent runtime"
  (it "discards a stale in-flight result after invalidation"
    (let* ((path "/root/stale/")
           (started (cl-concurrent-kit:make-channel :buffer-size 1))
           (release (cl-concurrent-kit:make-channel :buffer-size 1))
           (runtime
             (loom/feature/file-tree:make-loom-concurrent-runtime
              :directory-lister
              (lambda (requested-path)
                (cl-concurrent-kit:send started requested-path)
                (cl-concurrent-kit:recv release)
                (list (cons "/root/stale/old-file" :file))))))
      (unwind-protect
           (multiple-value-bind (promises accepted)
               (loom/feature/file-tree:loom-concurrent-runtime-prefetch runtime (list path))
             (declare (ignore accepted))
             (let ((promise (first promises)))
               (multiple-value-bind (started-path received-p)
                   (cl-concurrent-kit:recv
                    started
                    :timeout (%concurrent-runtime-test-timeout))
                 (expect started-path :to-equal path)
                 (expect received-p :to-be t))
               (multiple-value-bind (value received-p closed-p)
                   (cl-concurrent-kit:try-recv started)
                 (expect value :to-be nil)
                 (expect received-p :to-be nil)
                 (expect closed-p :to-be nil))
               (loom/feature/file-tree:loom-concurrent-runtime-invalidate-directory
                runtime path)
               (expect
                (loom/feature/file-tree:loom-concurrent-runtime-directory-entries runtime path)
                :to-be nil)
               (expect (cl-concurrent-kit:try-send release :release)
                       :to-be-truthy)
               (cl-concurrent-kit:await
                promise
                :timeout (%concurrent-runtime-test-timeout))
               (loom/feature/file-tree:loom-concurrent-runtime-drain runtime)
               (expect
                (loom/feature/file-tree:loom-concurrent-runtime-directory-entries runtime path)
                :to-be nil)
               (multiple-value-bind (fresh-promises fresh-accepted)
                   (loom/feature/file-tree:loom-concurrent-runtime-prefetch runtime (list path))
                 (expect fresh-accepted :to-be 1)
                 (let ((fresh-promise (first fresh-promises)))
                   (multiple-value-bind (fresh-started-path fresh-received-p)
                       (cl-concurrent-kit:recv
                        started
                        :timeout (%concurrent-runtime-test-timeout))
                     (expect fresh-started-path :to-equal path)
                     (expect fresh-received-p :to-be t))
                   (expect (cl-concurrent-kit:try-send release :release)
                           :to-be-truthy)
                   (cl-concurrent-kit:await
                    fresh-promise
                    :timeout (%concurrent-runtime-test-timeout))
                   (loom/feature/file-tree:loom-concurrent-runtime-drain runtime)
                   (expect
                    (loom/feature/file-tree:loom-concurrent-runtime-directory-entries runtime path)
                    :to-equal
                    (list (cons "/root/stale/old-file" :file)))))))
        (ignore-errors
          (cl-concurrent-kit:try-send release :cleanup))
        (ignore-errors
          (cl-concurrent-kit:close-channel started))
        (ignore-errors
          (cl-concurrent-kit:close-channel release))
        (ignore-errors
          (loom/feature/file-tree:loom-concurrent-runtime-shutdown runtime))))))
