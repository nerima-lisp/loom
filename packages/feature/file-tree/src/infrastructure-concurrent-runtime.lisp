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

(defun %submit-directory-listing (runtime path key generation)
  (let ((result-channel (loom-concurrent-runtime-result-channel runtime))
        (directory-lister (loom-concurrent-runtime-directory-lister runtime)))
    (lambda ()
      (handler-case
          (let ((entries (funcall directory-lister path)))
            (cl-concurrent-kit:send
             result-channel
             (list :kind :entries
                   :key key
                   :generation generation
                   :entries entries))
            entries)
        (error (condition)
          (cl-concurrent-kit:send
           result-channel
           (list :kind :error
                 :key key
                 :generation generation
                 :condition condition))
          (error condition))))))

(defun loom-concurrent-runtime-prefetch (runtime paths)
  "Submit uncached PATHS and return promises plus the accepted task count.

The runtime limits accepted tasks to the number of result slots available, so
workers cannot block forever trying to report a result while the main lane is
shutting down."
  (let ((promises (list))
        (accepted 0)
        (pending (loom-concurrent-runtime-pending runtime))
        (cache (loom-concurrent-runtime-directory-cache runtime))
        (errors (loom-concurrent-runtime-errors runtime))
        (generation-table (loom-concurrent-runtime-generation runtime)))
    (labels ((submit-path (path key generation)
               (setf (gethash key pending) generation)
               (handler-case
                   (cl-concurrent-kit:try-submit
                    (loom-concurrent-runtime-executor runtime)
                    (%submit-directory-listing
                     runtime path key generation))
                 (error (condition)
                   (remhash key pending)
                   (error condition)))))
      (dolist (path paths (values (nreverse promises) accepted))
        (when (and (not (loom-concurrent-runtime-closed-p runtime))
                   (< (hash-table-count pending)
                      (loom-concurrent-runtime-in-flight-limit runtime)))
          (let* ((key (%directory-key path))
                 (generation (gethash key generation-table 0)))
            (multiple-value-bind (cached cached-p) (gethash key cache)
              (declare (ignore cached))
              (let ((error-p (nth-value 1 (gethash key errors))))
                (multiple-value-bind (pending-generation pending-p)
                    (gethash key pending)
                  (declare (ignore pending-generation))
                  (unless (or cached-p error-p pending-p)
                    (multiple-value-bind (promise accepted-p)
                        (submit-path path key generation)
                      (if accepted-p
                          (progn
                            (push promise promises)
                            (incf accepted))
                          (remhash key pending)))))))))))))

(defun %apply-directory-result (runtime result)
  (let* ((key (getf result :key))
         (result-generation (getf result :generation))
         (pending (loom-concurrent-runtime-pending runtime))
         (generation-table (loom-concurrent-runtime-generation runtime)))
    (multiple-value-bind (pending-generation pending-p)
        (gethash key pending)
      (when (and pending-p (= pending-generation result-generation))
        (remhash key pending)))
    (when (= (gethash key generation-table 0) result-generation)
      (ecase (getf result :kind)
        (:entries
         (setf (gethash key
                        (loom-concurrent-runtime-directory-cache runtime))
               (getf result :entries))
         (remhash key (loom-concurrent-runtime-errors runtime)))
        (:error
         (remhash key (loom-concurrent-runtime-directory-cache runtime))
         (setf (gethash key (loom-concurrent-runtime-errors runtime))
               (getf result :condition)))))))

(defun loom-concurrent-runtime-drain (runtime)
  "Apply all currently available worker results on the calling thread."
  (let ((count 0)
        (channel (loom-concurrent-runtime-result-channel runtime)))
    (loop
      (multiple-value-bind (result ready closed)
          (cl-concurrent-kit:try-recv channel)
        (declare (ignore closed))
        (cond
          (ready
           (incf count)
           (%apply-directory-result runtime result))
          (t
           (return count)))))))

(defun loom-concurrent-runtime-shutdown (runtime)
  "Stop workers, then close the result channel, and return RUNTIME."
  (unless (loom-concurrent-runtime-closed-p runtime)
    (setf (loom-concurrent-runtime-closed-p runtime) t)
    (unwind-protect
      (cl-concurrent-kit:shutdown-executor
          (loom-concurrent-runtime-executor runtime)
          :wait t
          :cancel-pending t)
      (clrhash (loom-concurrent-runtime-pending runtime))
      (cl-concurrent-kit:close-channel
       (loom-concurrent-runtime-result-channel runtime))))
  runtime)
