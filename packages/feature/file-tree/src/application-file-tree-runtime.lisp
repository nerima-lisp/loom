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
                                        (values entries present-p))))
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

(defun file-tree-prepare-viewport (tree width height &key wheel-delta)
  "Prepare one entry prefix, preserving viewport state until listings are ready."
  (let* ((needed-p (file-tree-scroll-follow-needed-p tree))
         (follow-p (and needed-p (plusp height) (file-tree-selected-path tree)))
         (margin (if follow-p (%file-tree-scroll-margin height) 0))
         (forward-rows (max 0 (or wheel-delta 0)))
         (top (file-tree-scroll-top tree))
         (limit (+ top height margin forward-rows)))
    (multiple-value-bind (entries present-p)
        (file-tree-entries tree :limit limit
                          :stop-after-path (when follow-p
                                             (file-tree-selected-path tree))
                          :trailing-rows (+ margin forward-rows))
      (when present-p
        (let* ((count (length entries))
               (index (position (file-tree-selected-path tree) entries
                                :key #'car :test #'equal))
               (top (if follow-p
                        (file-tree-scroll-top-for-selection top index count height)
                        (file-tree-clamp-scroll-top top count height))))
          (when wheel-delta
            (setf top (file-tree-scroll-top-for-wheel top count height wheel-delta)))
          (setf (file-tree-scroll-top tree) top
                (file-tree-viewport-width tree) (min 24 width)
                (file-tree-viewport-height tree) height
                (file-tree-scroll-follow-needed-p tree)
                (and needed-p (zerop height)))))
      (values entries present-p))))

