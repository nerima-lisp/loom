(in-package #:loom/feature/file-tree)

(defun %clear-completed-directory-task (runtime key generation)
  (let ((pending (loom-concurrent-runtime-pending runtime)))
    (multiple-value-bind (pending-generation pending-p)
        (gethash key pending)
      (when (and pending-p (= pending-generation generation))
        (remhash key pending)))))

(defun %store-directory-result (runtime result)
  (let ((key (getf result :key)))
    (ecase (getf result :kind)
      (:entries
       (setf (gethash key
                      (loom-concurrent-runtime-directory-cache runtime))
             (getf result :entries))
       (remhash key (loom-concurrent-runtime-errors runtime)))
      (:error
       (remhash key (loom-concurrent-runtime-directory-cache runtime))
       (setf (gethash key (loom-concurrent-runtime-errors runtime))
             (getf result :condition))))))

(defun %directory-result-current-p (runtime key generation)
  "Return true when GENERATION is still current for KEY."
  (= (gethash key (loom-concurrent-runtime-generation runtime) 0)
     generation))

(defun %apply-directory-result (runtime result)
  (let* ((key (getf result :key))
         (result-generation (getf result :generation)))
    (%clear-completed-directory-task runtime key result-generation)
    (when (%directory-result-current-p runtime key result-generation)
      (%store-directory-result runtime result))))

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
