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
      (loom/feature/file-tree:loom-concurrent-runtime-prefetch runtime paths)
    (declare (ignore accepted))
    (dolist (promise promises)
      (cl-concurrent-kit:await
       promise
       :timeout (%concurrent-runtime-test-timeout)))
    promises))

(defmacro %with-concurrent-runtime ((runtime &rest initargs) &body body)
  `(let ((,runtime
           (loom/feature/file-tree:make-loom-concurrent-runtime
            ,@initargs)))
     (unwind-protect
          (progn ,@body)
       (ignore-errors
         (loom/feature/file-tree:loom-concurrent-runtime-shutdown ,runtime)))))

(defun %expect-prefetch-not-accepted (runtime path)
  (multiple-value-bind (promises accepted)
      (loom/feature/file-tree:loom-concurrent-runtime-prefetch runtime (list path))
    (expect promises :to-be nil)
    (expect accepted :to-be 0)))
