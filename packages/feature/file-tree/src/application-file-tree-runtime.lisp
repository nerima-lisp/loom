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

(defun file-tree-prepare-viewport (tree width height &key wheel-delta)
  "Apply selection following or wheel movement to the current sidebar geometry."
  (let* ((follow-p (or (file-tree-scroll-follow-p tree)
                       (/= height (file-tree-viewport-height tree))))
         (top (if follow-p
                  (file-tree-scroll-top-for-selection
                   (file-tree-scroll-top tree)
                   (file-tree-selection-index tree)
                   (file-tree-entry-count tree) height)
                  (file-tree-scroll-top tree)))
         (limit (+ top height
                   (if follow-p (%file-tree-scroll-margin height) 0)
                   (max 0 (or wheel-delta 0))))
         (entries (file-tree-entries
                   tree limit
                   :stop-after-path (when follow-p (file-tree-selected-path tree))
                   :trailing-rows (if follow-p (%file-tree-scroll-margin height) 0)))
         (count (length entries))
         (index (when follow-p
                  (position (file-tree-selected-path tree) entries
                            :key #'car :test #'equal)))
         (top (if follow-p
                  (file-tree-scroll-top-for-selection top index count height)
                  (file-tree-clamp-scroll-top top count height))))
    (when wheel-delta
      (setf top (file-tree-scroll-top-for-wheel top count height wheel-delta)))
    (setf (file-tree-scroll-top tree) top
          (file-tree-viewport-width tree) (min 24 width)
          (file-tree-viewport-height tree) height
          (file-tree-scroll-follow-p tree)
          (and (file-tree-scroll-follow-p tree) (null wheel-delta))
          (file-tree-scroll-follow-needed-p tree) nil
          (file-tree-entry-count tree)
          (if (< count limit) count (max count (file-tree-entry-count tree))))
    (when index
      (setf (file-tree-selection-index tree) index))
    tree))

