(in-package #:loom/test)

(describe "loom concurrent runtime"
  (it "shuts down idempotently and completes"
    (let* ((runtime
             (loom/feature/file-tree:make-loom-concurrent-runtime
              :directory-lister (lambda (path)
                                  (declare (ignore path))
                                  nil)))
           (shutdown-promise
             (cl-concurrent-kit:future
               (loom/feature/file-tree:loom-concurrent-runtime-shutdown runtime)
               (loom/feature/file-tree:loom-concurrent-runtime-shutdown runtime)
               :shutdown-complete)))
      (expect
       (cl-concurrent-kit:await
        shutdown-promise
        :timeout (%concurrent-runtime-test-timeout))
       :to-be :shutdown-complete)
      (expect (loom/feature/file-tree:loom-concurrent-runtime-drain runtime)
              :to-be 0)))

  (it "clears pending after shutdown without draining worker results"
    (let* ((path "/root/shutdown/")
           (started (cl-concurrent-kit:make-channel :buffer-size 1))
           (release (cl-concurrent-kit:make-channel :buffer-size 1))
           (runtime
             (loom/feature/file-tree:make-loom-concurrent-runtime
              :parallelism 1
              :queue-capacity 1
              :directory-lister
              (lambda (requested-path)
                (cl-concurrent-kit:send started requested-path)
                (cl-concurrent-kit:recv release)
                nil))))
      (unwind-protect
           (multiple-value-bind (promises accepted)
               (loom/feature/file-tree:loom-concurrent-runtime-prefetch runtime (list path))
             (expect accepted :to-be 1)
             (expect (hash-table-count
                      (loom/feature/file-tree::loom-concurrent-runtime-pending runtime))
                     :to-be 1)
             (multiple-value-bind (started-path received-p)
                 (cl-concurrent-kit:recv
                  started
                  :timeout (%concurrent-runtime-test-timeout))
               (expect started-path :to-equal path)
               (expect received-p :to-be t))
             (let ((shutdown-promise
                     (cl-concurrent-kit:future
                       (loom/feature/file-tree:loom-concurrent-runtime-shutdown runtime)
                       :shutdown-complete)))
               (expect (cl-concurrent-kit:try-send release :release)
                       :to-be-truthy)
               (cl-concurrent-kit:await
                shutdown-promise
                :timeout (%concurrent-runtime-test-timeout))
               (cl-concurrent-kit:await
                (first promises)
                :timeout (%concurrent-runtime-test-timeout))
               (expect (hash-table-count
                        (loom/feature/file-tree::loom-concurrent-runtime-pending runtime))
                       :to-be 0)))
        (ignore-errors
          (cl-concurrent-kit:try-send release :cleanup))
        (ignore-errors
          (cl-concurrent-kit:close-channel started))
        (ignore-errors
          (cl-concurrent-kit:close-channel release))
        (ignore-errors
          (loom/feature/file-tree:loom-concurrent-runtime-shutdown runtime)))))

  (it-each ((:closed-result-channel)
            (:no-ready-result))
      "returns zero when drain has nothing to process (~A)" (label)
    (%with-concurrent-runtime (runtime)
      (ecase label
        (:closed-result-channel
         (cl-concurrent-kit:close-channel
          (loom/feature/file-tree::loom-concurrent-runtime-result-channel runtime)))
        (:no-ready-result nil))
      (expect (loom/feature/file-tree:loom-concurrent-runtime-drain runtime)
              :to-be 0)))

  (it "closes the result channel when executor construction fails"
    (let ((closed-channel nil))
      (with-replaced-function
          (cl-concurrent-kit:make-executor
           (lambda (&rest arguments)
             (declare (ignore arguments))
             (error "executor unavailable")))
        (with-replaced-function
            (cl-concurrent-kit:close-channel
             (lambda (channel)
               (setf closed-channel channel)))
          (handler-case
              (loom/feature/file-tree:make-loom-concurrent-runtime)
            (error (condition)
              (expect (princ-to-string condition)
                      :to-contain "executor unavailable")))))
      (expect closed-channel :to-be-truthy))))
