;;;; packages/core/editor/src/application-commands-yank-pop-support.lisp
;;;;
;;;; Application layer: yank-pop helpers layered on top of yank support.
(in-package #:loom)

(defun %valid-yank-pop-context-p (buffer ring start end ranges last-buffer index)
  (and ring
       last-buffer
       (eq buffer last-buffer)
       (integerp start)
       (integerp end)
       (consp ranges)
       (integerp index)
       (= (buffer-point-offset buffer) end)))

(defun %yank-pop-context (buffer)
  (let* ((ring (editor-state-kill-ring *editor-state*))
         (start (editor-state-last-yank-start-offset *editor-state*))
         (end (editor-state-last-yank-end-offset *editor-state*))
         (ranges (editor-state-last-yank-ranges *editor-state*))
         (last-buffer (editor-state-last-yank-buffer *editor-state*))
         (index (editor-state-last-yank-ring-index *editor-state*))
         (repeat-count
           (max 1 (or (editor-state-last-yank-repeat-count *editor-state*)
                      1))))
    (when (%valid-yank-pop-context-p buffer ring start end ranges last-buffer index)
      (values ring start ranges index repeat-count))))

(defun %replace-yank-ranges (buffer ranges replacement)
  "Replace each half-open RANGE in BUFFER with REPLACEMENT.

The ranges use the buffer offsets from before any replacement. Editing from
right to left preserves those offsets; the returned ranges use the resulting
buffer coordinates and retain the original range order."
  (let ((replacement-length (length replacement)))
    (dolist (range (sort (copy-list ranges) #'> :key #'car))
      (let* ((start (buffer-offset-position buffer (car range)))
             (end (buffer-offset-position buffer (cdr range))))
        (buffer-delete-region buffer
                              (buffer-position-line start)
                              (buffer-position-column start)
                              (buffer-position-line end)
                              (buffer-position-column end))
        (buffer-insert-string buffer replacement)))
    (mapcar
     (lambda (range)
       (let* ((old-start (car range))
              (left-shift
                (loop for other in ranges
                      when (<= (cdr other) old-start)
                        sum (- replacement-length
                               (- (cdr other) (car other))))))
         (cons (+ old-start left-shift)
               (+ old-start left-shift replacement-length))))
     ranges)))

(defun %perform-yank-pop (buffer ring start ranges index repeat-count)
  (let* ((next-index (mod (+ index (%command-prefix-count))
                          (length ring)))
         (replacement (%repeat-kill-text (nth next-index ring) repeat-count))
         (new-ranges (%replace-yank-ranges buffer ranges replacement))
         (primary-index (or (position start ranges :key #'car :test #'=)
                            0))
         (primary-range (nth primary-index new-ranges))
         (primary-position
           (buffer-offset-position buffer (cdr primary-range))))
    (buffer-set-point buffer
                      (buffer-position-line primary-position)
                      (buffer-position-column primary-position))
    (%record-last-yank buffer new-ranges
                       :ring-index next-index
                       :repeat-count repeat-count)))
