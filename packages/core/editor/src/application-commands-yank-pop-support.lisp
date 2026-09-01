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

(defun %yank-pop-repeat-count ()
  (max 1 (or (editor-state-last-yank-repeat-count *editor-state*)
             1)))

(defun %yank-pop-state ()
  (values (editor-state-kill-ring *editor-state*)
          (editor-state-last-yank-start-offset *editor-state*)
          (editor-state-last-yank-end-offset *editor-state*)
          (editor-state-last-yank-ranges *editor-state*)
          (editor-state-last-yank-buffer *editor-state*)
          (editor-state-last-yank-ring-index *editor-state*)
          (%yank-pop-repeat-count)))

(defun %yank-pop-context (buffer)
  (multiple-value-bind (ring start end ranges last-buffer index repeat-count)
      (%yank-pop-state)
    (when (%valid-yank-pop-context-p buffer ring start end ranges last-buffer index)
      (values ring start ranges index repeat-count))))

(defun %yank-ranges-in-replacement-order (ranges)
  (sort (copy-list ranges) #'> :key #'car))

(defun %replace-yank-ranges (buffer ranges replacement)
  "Replace each half-open RANGE in BUFFER with REPLACEMENT.

The ranges use the buffer offsets from before any replacement. Editing from
right to left preserves those offsets; the returned ranges use the resulting
  buffer coordinates and retain the original range order."
  (let ((replacement-length (length replacement)))
    (dolist (range (%yank-ranges-in-replacement-order ranges))
      (%replace-yank-range buffer range replacement))
    (%yank-replacement-ranges ranges replacement-length)))

(defun %yank-replacement-ranges (ranges replacement-length)
  (mapcar
   (lambda (range)
     (let* ((old-start (car range))
            (left-shift (%yank-range-left-shift ranges old-start
                                                 replacement-length)))
       (cons (+ old-start left-shift)
             (+ old-start left-shift replacement-length))))
   ranges))

(defun %replace-yank-range (buffer range replacement)
  (let* ((start (buffer-offset-position buffer (car range)))
         (end (buffer-offset-position buffer (cdr range))))
    (buffer-delete-region buffer
                          (buffer-position-line start)
                          (buffer-position-column start)
                          (buffer-position-line end)
                          (buffer-position-column end))
    (buffer-insert-string buffer replacement)))

(defun %yank-range-left-shift (ranges old-start replacement-length)
  (loop for other in ranges
        when (<= (cdr other) old-start)
          sum (- replacement-length
                 (- (cdr other) (car other)))))

(defun %next-yank-pop-index (ring index)
  (mod (+ index (%command-prefix-count))
       (length ring)))

(defun %yank-pop-primary-range (start ranges new-ranges)
  (let ((primary-index (or (position start ranges :key #'car :test #'=)
                           0)))
    (nth primary-index new-ranges)))

(defun %set-point-at-offset (buffer offset)
  (let ((position (buffer-offset-position buffer offset)))
    (buffer-set-point buffer
                      (buffer-position-line position)
                      (buffer-position-column position))))

(defun %perform-yank-pop (buffer ring start ranges index repeat-count)
  (let* ((next-index (%next-yank-pop-index ring index))
         (replacement (%repeat-kill-text (nth next-index ring) repeat-count))
         (new-ranges (%replace-yank-ranges buffer ranges replacement))
         (primary-range (%yank-pop-primary-range start ranges new-ranges)))
    (%set-point-at-offset buffer (cdr primary-range))
    (%record-last-yank buffer new-ranges
                       :ring-index next-index
                       :repeat-count repeat-count)))
