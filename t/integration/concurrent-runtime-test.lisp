(in-package #:loom/test)

(defun %concurrent-runtime-test-timeout ()
  (cl-date-kit:duration-of-seconds 1))

(defun %make-counting-directory-lister (entries-by-path)
  (let ((counters
          (mapcar (lambda (entry)
                    (cons (car entry)
                          (cl-concurrent-kit:make-atomic-counter)))
                  entries-by-path)))
    (values
     (lambda (path)
       (let ((counter-entry (assoc path counters :test #'equal))
             (entries-entry (assoc path entries-by-path :test #'equal)))
         (unless (and counter-entry entries-entry)
           (error "Unexpected directory path: ~S" path))
         (cl-concurrent-kit:atomic-counter-incf (cdr counter-entry))
         (cdr entries-entry)))
     (lambda (path)
       (let ((counter-entry (assoc path counters :test #'equal)))
         (unless counter-entry
           (error "Unexpected directory path count: ~S" path))
         (cl-concurrent-kit:atomic-counter-value (cdr counter-entry)))))))

(defun %await-prefetch (runtime paths)
  (multiple-value-bind (promises accepted)
      (loom::loom-concurrent-runtime-prefetch runtime paths)
    (declare (ignore accepted))
    (dolist (promise promises)
      (cl-concurrent-kit:await
       promise
       :timeout (%concurrent-runtime-test-timeout)))
    promises))

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
                (loom::make-loom-concurrent-runtime
                 :directory-lister lister)))
          (unwind-protect
               (progn
                 (expect
                  (loom::loom-concurrent-runtime-directory-lister runtime)
                  :to-be lister)
                 (%await-prefetch runtime (list path-b path-a path-b))
                 (loom::loom-concurrent-runtime-drain runtime)
                 (expect
                  (mapcar
                   (lambda (path)
                     (loom::loom-concurrent-runtime-directory-entries
                      runtime path))
                   (list path-b path-a path-b))
                  :to-equal (list entries-b entries-a entries-b))
                 (expect (funcall call-count path-a) :to-be 1)
                 (expect (funcall call-count path-b) :to-be 1)
                 (%await-prefetch runtime (list path-a path-b))
                 (loom::loom-concurrent-runtime-drain runtime)
                 (expect (funcall call-count path-a) :to-be 1)
                 (expect (funcall call-count path-b) :to-be 1))
            (ignore-errors
              (loom::loom-concurrent-runtime-shutdown runtime)))))))

  (it "deduplicates relative and absolute spellings of the same directory"
    (let* ((relative-path ".")
           (absolute-path (namestring (truename ".")))
           (call-count (cl-concurrent-kit:make-atomic-counter))
           (runtime
             (loom::make-loom-concurrent-runtime
              :directory-lister
              (lambda (path)
                (declare (ignore path))
                (cl-concurrent-kit:atomic-counter-incf call-count)
                nil))))
      (unwind-protect
           (multiple-value-bind (promises accepted)
               (loom::loom-concurrent-runtime-prefetch
                runtime
                (list relative-path absolute-path))
             (expect accepted :to-be 1)
             (dolist (promise promises)
               (cl-concurrent-kit:await
                promise
                :timeout (%concurrent-runtime-test-timeout)))
             (loom::loom-concurrent-runtime-drain runtime)
             (expect (cl-concurrent-kit:atomic-counter-value call-count)
                     :to-be 1))
        (ignore-errors
          (loom::loom-concurrent-runtime-shutdown runtime)))))

  (it "re-signals a worker error when a prefetch promise is awaited"
    (let ((runtime
            (loom::make-loom-concurrent-runtime
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
             (loom::loom-concurrent-runtime-drain runtime)
             (multiple-value-bind (directory-error present-p)
                 (loom::loom-concurrent-runtime-directory-error
                  runtime
                  "/broken/")
               (expect present-p :to-be-truthy)
               (expect (search "broken directory lister"
                               (princ-to-string directory-error))
                       :to-be-truthy))
             (multiple-value-bind (promises accepted)
                 (loom::loom-concurrent-runtime-prefetch
                  runtime
                  (list "/broken/"))
               (declare (ignore promises))
               (expect accepted :to-be 0)))
        (ignore-errors
          (loom::loom-concurrent-runtime-shutdown runtime)))))

  (it "primes and invalidates a path together with its parent"
    (let ((runtime
            (loom::make-loom-concurrent-runtime
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
              (loom::loom-concurrent-runtime-prime-directory
               runtime
               parent
               parent-entries)
              :to-be parent-entries)
             (expect
              (loom::loom-concurrent-runtime-prime-directory
               runtime
               path
               path-entries)
              :to-be path-entries)
             (multiple-value-bind (entries present-p)
                 (loom::loom-concurrent-runtime-directory-entries
                  runtime
                  parent)
               (expect entries :to-be parent-entries)
               (expect present-p :to-be-truthy))
             (multiple-value-bind (entries present-p)
                 (loom::loom-concurrent-runtime-directory-entries
                  runtime
                  path)
               (expect entries :to-be path-entries)
               (expect present-p :to-be-truthy))
             (loom::loom-concurrent-runtime-invalidate-path runtime path)
             (multiple-value-bind (entries present-p)
                 (loom::loom-concurrent-runtime-directory-entries
                  runtime
                  parent)
               (declare (ignore entries))
               (expect present-p :to-be nil))
             (multiple-value-bind (entries present-p)
                 (loom::loom-concurrent-runtime-directory-entries
                  runtime
                  path)
               (declare (ignore entries))
               (expect present-p :to-be nil)))
        (ignore-errors
          (loom::loom-concurrent-runtime-shutdown runtime)))))

  (it "invalidates a directory only once when its parent is itself"
    (let ((runtime
            (loom::make-loom-concurrent-runtime
             :directory-lister
             (lambda (path)
               (declare (ignore path))
               nil))))
      (unwind-protect
           (let* ((path "/root/child/")
                  (key (loom::%directory-key path))
                  (entries '(("/root/child/file.txt" . :file)))
                  (generation-table
                    (loom::loom-concurrent-runtime-generation runtime)))
             (loom::loom-concurrent-runtime-prime-directory
              runtime
              path
              entries)
             (let ((generation-before (gethash key generation-table 0)))
               (loom::loom-concurrent-runtime-invalidate-path runtime path)
               (multiple-value-bind (cached present-p)
                   (loom::loom-concurrent-runtime-directory-entries
                    runtime
                    path)
                 (declare (ignore cached))
                 (expect present-p :to-be nil))
               (expect (gethash key generation-table)
                       :to-be
                       (1+ generation-before))))
        (ignore-errors
          (loom::loom-concurrent-runtime-shutdown runtime)))))

  (it "drops a stale pending task when priming an in-flight directory"
    (let* ((path "/root/primed/")
           (started (cl-concurrent-kit:make-channel :buffer-size 1))
           (release (cl-concurrent-kit:make-channel :buffer-size 1))
           (primed-entries '(("/root/primed/primed-file" . :file)))
           (runtime
             (loom::make-loom-concurrent-runtime
              :directory-lister
              (lambda (requested-path)
                (cl-concurrent-kit:send started requested-path)
                (cl-concurrent-kit:recv release)
                '(("/root/primed/stale-file" . :file))))))
      (unwind-protect
           (multiple-value-bind (promises accepted)
               (loom::loom-concurrent-runtime-prefetch runtime (list path))
             (expect accepted :to-be 1)
             (let ((promise (first promises)))
               (multiple-value-bind (started-path received-p)
                   (cl-concurrent-kit:recv
                    started
                    :timeout (%concurrent-runtime-test-timeout))
                 (expect started-path :to-equal path)
                 (expect received-p :to-be t))
               (loom::loom-concurrent-runtime-prime-directory
                runtime
                path
                primed-entries)
               (expect (hash-table-count
                        (loom::loom-concurrent-runtime-pending runtime))
                       :to-be 0)
               (expect (cl-concurrent-kit:try-send release :release)
                       :to-be-truthy)
               (cl-concurrent-kit:await
                promise
                :timeout (%concurrent-runtime-test-timeout))
               (loom::loom-concurrent-runtime-drain runtime)
               (expect
                (loom::loom-concurrent-runtime-directory-entries runtime path)
                :to-equal primed-entries)))
        (ignore-errors
          (cl-concurrent-kit:try-send release :cleanup))
        (ignore-errors
          (cl-concurrent-kit:close-channel started))
        (ignore-errors
          (cl-concurrent-kit:close-channel release))
        (ignore-errors
          (loom::loom-concurrent-runtime-shutdown runtime)))))

  (it "discards a stale in-flight result after invalidation"
    (let* ((path "/root/stale/")
           (started (cl-concurrent-kit:make-channel :buffer-size 1))
           (release (cl-concurrent-kit:make-channel :buffer-size 1))
           (runtime
             (loom::make-loom-concurrent-runtime
              :directory-lister
              (lambda (requested-path)
                (cl-concurrent-kit:send started requested-path)
                (cl-concurrent-kit:recv release)
                (list (cons "/root/stale/old-file" :file))))))
      (unwind-protect
           (multiple-value-bind (promises accepted)
               (loom::loom-concurrent-runtime-prefetch runtime (list path))
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
               (loom::loom-concurrent-runtime-invalidate-directory
                runtime path)
               (expect
                (loom::loom-concurrent-runtime-directory-entries runtime path)
                :to-be nil)
               (expect (cl-concurrent-kit:try-send release :release)
                       :to-be-truthy)
               (cl-concurrent-kit:await
                promise
                :timeout (%concurrent-runtime-test-timeout))
               (loom::loom-concurrent-runtime-drain runtime)
               (expect
                (loom::loom-concurrent-runtime-directory-entries runtime path)
                :to-be nil)
               (multiple-value-bind (fresh-promises fresh-accepted)
                   (loom::loom-concurrent-runtime-prefetch runtime (list path))
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
                   (loom::loom-concurrent-runtime-drain runtime)
                   (expect
                    (loom::loom-concurrent-runtime-directory-entries runtime path)
                    :to-equal
                    (list (cons "/root/stale/old-file" :file)))))))
        (ignore-errors
          (cl-concurrent-kit:try-send release :cleanup))
        (ignore-errors
          (cl-concurrent-kit:close-channel started))
        (ignore-errors
          (cl-concurrent-kit:close-channel release))
        (ignore-errors
          (loom::loom-concurrent-runtime-shutdown runtime)))))

  (it "shuts down idempotently and completes"
    (let* ((runtime
             (loom::make-loom-concurrent-runtime
              :directory-lister (lambda (path)
                                  (declare (ignore path))
                                  nil)))
           (shutdown-promise
             (cl-concurrent-kit:future
               (loom::loom-concurrent-runtime-shutdown runtime)
               (loom::loom-concurrent-runtime-shutdown runtime)
               :shutdown-complete)))
      (expect
       (cl-concurrent-kit:await
        shutdown-promise
        :timeout (%concurrent-runtime-test-timeout))
       :to-be :shutdown-complete)
      (expect (loom::loom-concurrent-runtime-drain runtime)
              :to-be 0)))

  (it "clears pending after shutdown without draining worker results"
    (let* ((path "/root/shutdown/")
           (started (cl-concurrent-kit:make-channel :buffer-size 1))
           (release (cl-concurrent-kit:make-channel :buffer-size 1))
           (runtime
             (loom::make-loom-concurrent-runtime
              :parallelism 1
              :queue-capacity 1
              :directory-lister
              (lambda (requested-path)
                (cl-concurrent-kit:send started requested-path)
                (cl-concurrent-kit:recv release)
                nil))))
      (unwind-protect
           (multiple-value-bind (promises accepted)
               (loom::loom-concurrent-runtime-prefetch runtime (list path))
             (expect accepted :to-be 1)
             (expect (hash-table-count
                      (loom::loom-concurrent-runtime-pending runtime))
                     :to-be 1)
             (multiple-value-bind (started-path received-p)
                 (cl-concurrent-kit:recv
                  started
                  :timeout (%concurrent-runtime-test-timeout))
               (expect started-path :to-equal path)
               (expect received-p :to-be t))
             (let ((shutdown-promise
                     (cl-concurrent-kit:future
                       (loom::loom-concurrent-runtime-shutdown runtime)
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
                        (loom::loom-concurrent-runtime-pending runtime))
                       :to-be 0)))
        (ignore-errors
          (cl-concurrent-kit:try-send release :cleanup))
        (ignore-errors
          (cl-concurrent-kit:close-channel started))
        (ignore-errors
          (cl-concurrent-kit:close-channel release))
        (ignore-errors
          (loom::loom-concurrent-runtime-shutdown runtime)))))

  (it "returns zero when the result channel is already closed"
    (let ((runtime (loom::make-loom-concurrent-runtime)))
      (unwind-protect
           (progn
             (cl-concurrent-kit:close-channel
              (loom::loom-concurrent-runtime-result-channel runtime))
             (expect (loom::loom-concurrent-runtime-drain runtime)
                     :to-be 0))
        (ignore-errors
          (loom::loom-concurrent-runtime-shutdown runtime)))))

  (it "returns zero when no result is ready"
    (let ((runtime (loom::make-loom-concurrent-runtime)))
      (unwind-protect
           (expect (loom::loom-concurrent-runtime-drain runtime)
                   :to-be 0)
        (ignore-errors
          (loom::loom-concurrent-runtime-shutdown runtime)))))

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
              (loom::make-loom-concurrent-runtime)
            (error (condition)
              (expect (princ-to-string condition)
                      :to-contain "executor unavailable")))))
      (expect closed-channel :to-be-truthy)))

  (it "removes a path from pending when submission is rejected"
    (let ((runtime (loom::make-loom-concurrent-runtime)))
      (unwind-protect
           (with-replaced-function
               (cl-concurrent-kit:try-submit
                (lambda (&rest arguments)
                  (declare (ignore arguments))
                  (values nil nil)))
             (multiple-value-bind (promises accepted)
                 (loom::loom-concurrent-runtime-prefetch
                  runtime
                  (list "/rejected/"))
               (expect promises :to-be nil)
               (expect accepted :to-be 0)
               (expect (hash-table-count
                        (loom::loom-concurrent-runtime-pending runtime))
                       :to-be 0)))
        (ignore-errors
          (loom::loom-concurrent-runtime-shutdown runtime)))))

  (it "removes a path from pending when submission signals an error"
    (let ((runtime (loom::make-loom-concurrent-runtime))
          (condition nil))
      (unwind-protect
           (progn
             (with-replaced-function
                 (cl-concurrent-kit:try-submit
                  (lambda (&rest arguments)
                    (declare (ignore arguments))
                    (error "executor unavailable")))
               (handler-case
                   (loom::loom-concurrent-runtime-prefetch
                    runtime
                    (list "/error/"))
                 (error (caught-condition)
                   (setf condition caught-condition))))
             (expect condition :to-be-truthy)
             (expect (princ-to-string condition)
                     :to-contain "executor unavailable")
             (expect (hash-table-count
                      (loom::loom-concurrent-runtime-pending runtime))
                     :to-be 0))
        (ignore-errors
          (loom::loom-concurrent-runtime-shutdown runtime)))))

  (it "does not prefetch after close or when capacity is full"
    (let ((runtime
            (loom::make-loom-concurrent-runtime
             :parallelism 1
             :queue-capacity 1)))
      (unwind-protect
           (progn
             (setf (loom::loom-concurrent-runtime-closed-p runtime) t)
             (multiple-value-bind (promises accepted)
                 (loom::loom-concurrent-runtime-prefetch
                  runtime
                  (list "/closed/"))
               (expect promises :to-be nil)
               (expect accepted :to-be 0))
             (setf (loom::loom-concurrent-runtime-closed-p runtime) nil)
             (setf (gethash "/one/"
                            (loom::loom-concurrent-runtime-pending runtime))
                   :pending
                   (gethash "/two/"
                            (loom::loom-concurrent-runtime-pending runtime))
                   :pending)
             (multiple-value-bind (promises accepted)
                 (loom::loom-concurrent-runtime-prefetch
                  runtime
                  (list "/full/"))
               (expect promises :to-be nil)
               (expect accepted :to-be 0)))
        (ignore-errors
          (loom::loom-concurrent-runtime-shutdown runtime)))))
)
