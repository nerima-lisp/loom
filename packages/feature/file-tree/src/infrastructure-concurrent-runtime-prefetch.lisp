(in-package #:loom/feature/file-tree)

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

(defun %prefetch-slot-available-p (runtime pending)
  "Return true when RUNTIME can accept another directory task."
  (and (not (loom-concurrent-runtime-closed-p runtime))
       (< (hash-table-count pending)
          (loom-concurrent-runtime-in-flight-limit runtime))))

(defun %directory-state-present-p (table key)
  "Return true when TABLE contains an entry for KEY, including a NIL value."
  (nth-value 1 (gethash key table)))

(defun %directory-prefetch-needed-p (cache errors pending key)
  "Return true when KEY is neither cached, failed, nor already in flight."
  (not (or (%directory-state-present-p cache key)
           (%directory-state-present-p errors key)
           (%directory-state-present-p pending key))))

(defun %submit-directory-prefetch (runtime pending path key generation)
  "Submit PATH and remove its pending marker when submission is rejected.

Submission errors also clear the marker before being propagated to the caller,
so a failed executor cannot leave the runtime believing a task is in flight."
  (setf (gethash key pending) generation)
  (handler-case
      (multiple-value-bind (promise accepted-p)
          (cl-concurrent-kit:try-submit
           (loom-concurrent-runtime-executor runtime)
           (%submit-directory-listing runtime path key generation))
        (unless accepted-p
          (remhash key pending))
        (values promise accepted-p))
    (error (condition)
      (remhash key pending)
      (error condition))))

(defun %prefetch-directory-if-needed
    (runtime pending cache errors generation-table path)
  "Submit PATH when its directory state has not been resolved yet."
  (let* ((key (%directory-key path))
         (generation (gethash key generation-table 0)))
    (when (%directory-prefetch-needed-p cache errors pending key)
      (%submit-directory-prefetch runtime pending path key generation))))

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
    (dolist (path paths (values (nreverse promises) accepted))
        (when (%prefetch-slot-available-p runtime pending)
          (multiple-value-bind (promise accepted-p)
              (%prefetch-directory-if-needed
               runtime pending cache errors generation-table path)
            (when accepted-p
              (push promise promises)
              (incf accepted)))))))
