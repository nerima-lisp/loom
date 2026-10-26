(in-package #:loom/feature/file-tree)

(defun enable-file-tree-runtime (state)
  "Install the cached file-tree runtime for STATE."
  (let* ((tree (editor-state-file-tree state))
         (lister (file-tree-child-lister tree))
         (root (first (file-tree-prefetch-paths tree)))
         (initial-entries (funcall lister root))
         (runtime (make-loom-concurrent-runtime :directory-lister lister)))
    (loom-concurrent-runtime-prime-directory runtime root initial-entries)
    (file-tree-install-child-lister tree
                                    (lambda (path)
                                      (multiple-value-bind (entries present-p)
                                          (loom-concurrent-runtime-directory-entries
                                           runtime
                                           path)
                                        (when present-p
                                          entries))))
    (setf (editor-state-concurrent-runtime state) runtime)
    runtime))

(defun shutdown-file-tree-runtime (state)
  "Stop the asynchronous file-tree runtime attached to STATE."
  (let ((runtime (editor-state-concurrent-runtime state)))
    (when runtime
      (loom-concurrent-runtime-shutdown runtime))))

(defun refresh-file-tree-runtime (state)
  "Drain completed work and prefetch visible file-tree paths."
  (let ((runtime (editor-state-concurrent-runtime state)))
    (when runtime
      (loom-concurrent-runtime-drain runtime)
      (loom-concurrent-runtime-prefetch
       runtime
       (file-tree-prefetch-paths (editor-state-file-tree state))))))
(defun file-tree-runtime-background-work-p (state)
  "Whether a file-tree directory listing still needs to be drained."
  (let ((runtime (editor-state-concurrent-runtime state)))
    (and runtime
         (plusp
          (hash-table-count
           (loom-concurrent-runtime-pending runtime))))))

