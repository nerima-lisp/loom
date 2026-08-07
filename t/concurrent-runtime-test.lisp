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
             (multiple-value-bind (promises accepted)
                 (loom::loom-concurrent-runtime-prefetch
                  runtime
                  (list "/broken/"))
               (declare (ignore promises))
               (expect accepted :to-be 0)))
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
       :to-be :shutdown-complete))))
