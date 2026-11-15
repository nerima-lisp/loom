(in-package #:loom)

(defvar *syntax-line-caches* (make-hash-table :test #'eq :weakness :key)
  "Each buffer's syntax line-state cache, dropped with the buffer.")

(defun %syntax-line-cache-for-buffer (buffer)
  "Return BUFFER's line-state cache, revalidated from its first line changed
since the cache's buffer version."
  (let ((mode (buffer-major-mode buffer))
        (version (loom/core/buffer:buffer-version buffer))
        (cache (gethash buffer *syntax-line-caches*)))
    (cond ((or (null cache)
               (not (equal mode
                           (loom/feature/syntax-highlighting:syntax-line-cache-mode
                            cache))))
           (setf (gethash buffer *syntax-line-caches*)
                 (loom/feature/syntax-highlighting:make-syntax-line-cache
                  mode version)))
          (t
           (let ((cached (loom/feature/syntax-highlighting:syntax-line-cache-version
                          cache)))
             (unless (= version cached)
               (loom/feature/syntax-highlighting:syntax-line-cache-invalidate
                cache
                (loom/core/buffer:buffer-changed-line-since buffer cached)
                version)))
           cache))))

(defun %prepare-syntax-line-tokens (buffer line text)
  "Return syntax tokens for TEXT, the display text of BUFFER's visible LINE.

Call this in the same frame that draws TEXT, after the window viewport is
settled: the visible line becomes an absolute line using the current
narrowing, and the result is meant to be drawn for each wrapped row of LINE."
  (let* ((narrow-line (loom/core/buffer:buffer-narrow-start-line buffer))
         (absolute-line (+ line narrow-line))
         ;; Only the first narrowed line can start inside its absolute line.
         (offset (if (zerop line)
                     (- (loom/core/buffer:buffer-narrow-start-offset buffer)
                        (loom/core/buffer:buffer-position-offset
                         buffer narrow-line 0))
                     0)))
    (loom/feature/syntax-highlighting:syntax-cached-line-tokens
     (%syntax-line-cache-for-buffer buffer) buffer absolute-line text offset)))
