(in-package #:loom/test)

(describe "loom concurrent runtime"
  (it "removes a path from pending when submission is rejected"
    (%with-concurrent-runtime (runtime)
      (with-replaced-function
          (cl-concurrent-kit:try-submit
           (lambda (&rest arguments)
             (declare (ignore arguments))
             (values nil nil)))
        (%expect-prefetch-not-accepted runtime "/rejected/")
        (expect (hash-table-count
                 (loom/feature/file-tree::loom-concurrent-runtime-pending runtime))
                :to-be 0))))

  (it "removes a path from pending when submission signals an error"
    (%with-concurrent-runtime (runtime)
      (let ((condition nil))
        (with-replaced-function
            (cl-concurrent-kit:try-submit
             (lambda (&rest arguments)
               (declare (ignore arguments))
               (error "executor unavailable")))
          (handler-case
              (loom/feature/file-tree:loom-concurrent-runtime-prefetch
               runtime
               (list "/error/"))
            (error (caught-condition)
              (setf condition caught-condition))))
        (expect condition :to-be-truthy)
        (expect (princ-to-string condition)
                :to-contain "executor unavailable")
        (expect (hash-table-count
                 (loom/feature/file-tree::loom-concurrent-runtime-pending runtime))
                :to-be 0))))

  (it "does not prefetch after close or when capacity is full"
    (%with-concurrent-runtime (runtime
                               :parallelism 1
                               :queue-capacity 1)
      (setf (loom/feature/file-tree::loom-concurrent-runtime-closed-p runtime) t)
      (%expect-prefetch-not-accepted runtime "/closed/")
      (setf (loom/feature/file-tree::loom-concurrent-runtime-closed-p runtime) nil)
      (setf (gethash "/one/"
                     (loom/feature/file-tree::loom-concurrent-runtime-pending runtime))
            :pending
            (gethash "/two/"
                     (loom/feature/file-tree::loom-concurrent-runtime-pending runtime))
            :pending)
      (%expect-prefetch-not-accepted runtime "/full/"))))
