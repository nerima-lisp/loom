(in-package #:loom/feature/file-tree)

(defstruct (loom-concurrent-runtime
            (:constructor %make-loom-concurrent-runtime))
  executor
  result-channel
  directory-lister
  (directory-cache (make-hash-table :test #'equal))
  (pending (make-hash-table :test #'equal))
  (generation (make-hash-table :test #'equal))
  (errors (make-hash-table :test #'equal))
  in-flight-limit
  (closed-p nil))

(defun %directory-key (path)
  (namestring
   (host-kit:ensure-directory-pathname
    (host-kit:truenamize
     (host-kit:ensure-directory-pathname (pathname path))))))

(defun make-loom-concurrent-runtime
    (&key (directory-lister #'loom-fs-list-directory)
          (parallelism 4)
          (queue-capacity 64))
  "Create the asynchronous directory-listing runtime.

The result channel has room for every task that can be accepted by the
executor. This keeps shutdown bounded even when the main lane has not drained
results yet."
  (check-type directory-lister function)
  (check-type parallelism (integer 1))
  (check-type queue-capacity (integer 1))
  (let* ((in-flight-limit (+ parallelism queue-capacity))
         (result-channel
           (cl-concurrent-kit:make-channel
            :buffer-size in-flight-limit)))
    (handler-case
        (%make-loom-concurrent-runtime
         :executor
         (cl-concurrent-kit:make-executor
          :size parallelism
          :name "loom file-tree worker"
          :queue-capacity queue-capacity)
         :result-channel result-channel
         :directory-lister directory-lister
         :in-flight-limit in-flight-limit)
      (error (condition)
        (cl-concurrent-kit:close-channel result-channel)
        (error condition)))))

(defun loom-concurrent-runtime-directory-entries (runtime path)
  "Return cached entries for PATH and a flag indicating whether they exist."
  (gethash (%directory-key path)
           (loom-concurrent-runtime-directory-cache runtime)))

(defun loom-concurrent-runtime-directory-error (runtime path)
  "Return a cached listing error for PATH and a flag indicating whether it exists."
  (gethash (%directory-key path)
           (loom-concurrent-runtime-errors runtime)))

(defun loom-concurrent-runtime-prime-directory (runtime path entries)
  "Install the synchronous initial listing for PATH into RUNTIME."
  (let* ((key (%directory-key path))
         (generation (loom-concurrent-runtime-generation runtime)))
    (incf (gethash key generation 0))
    (setf (gethash key (loom-concurrent-runtime-directory-cache runtime))
          entries)
    (remhash key (loom-concurrent-runtime-errors runtime))
    (remhash key (loom-concurrent-runtime-pending runtime))
    entries))

(defun loom-concurrent-runtime-invalidate-directory (runtime path)
  "Invalidate the cached listing for PATH without cancelling a worker task."
  (let* ((key (%directory-key path))
         (generation (loom-concurrent-runtime-generation runtime)))
    (incf (gethash key generation 0))
    (remhash key (loom-concurrent-runtime-directory-cache runtime))
    (remhash key (loom-concurrent-runtime-errors runtime))
    (remhash key (loom-concurrent-runtime-pending runtime))
    runtime))

(defun loom-concurrent-runtime-invalidate-path (runtime path)
  "Invalidate PATH and its parent directory listing."
  (let* ((path-key (%directory-key path))
         (parent (host-kit:pathname-directory-pathname (pathname path))))
    (loom-concurrent-runtime-invalidate-directory runtime path)
    (unless (equal path-key (%directory-key parent))
      (loom-concurrent-runtime-invalidate-directory runtime parent)))
  runtime)
