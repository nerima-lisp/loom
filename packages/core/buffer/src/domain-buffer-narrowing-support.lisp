(in-package #:loom/core/buffer)

(defun %text-offset-to-position-values (text offset)
  "Return LINE and COLUMN for OFFSET in TEXT, clamped to TEXT's bounds."
  (let ((bounded-offset (max 0 (min offset (length text))))
        (line 0)
        (line-start 0))
    (loop for newline = (position #\Newline text :start line-start)
          while (and newline (> bounded-offset newline))
          do (incf line)
             (setf line-start (1+ newline))
          finally (return (values line (- bounded-offset line-start))))))

(defun %visible-line-scan (buffer &optional target-line)
  "Count visible lines, returning TARGET-LINE without building the complete text."
  (let ((visible-start (%buffer-narrow-start-offset buffer))
        (visible-end (%buffer-narrow-end-offset buffer))
        (cursor 0)
        (line-index 0)
        (line-count 1)
        (line-stream (and target-line (make-string-output-stream))))
    (dolist (piece (%buffer-pieces buffer))
      (when (>= cursor visible-end)
        (return))
      (let* ((piece-end (+ cursor (%piece-length piece)))
             (visible-piece-start (max visible-start cursor))
             (visible-piece-end (min visible-end piece-end)))
        (when (< visible-piece-start visible-piece-end)
          (let* ((source (%piece-source-text buffer piece))
                 (source-start
                   (+ (%piece-start piece) (- visible-piece-start cursor)))
                 (source-end
                   (+ (%piece-start piece) (- visible-piece-end cursor))))
            (loop with segment-start = source-start
                  for newline = (position #\Newline source
                                          :start segment-start
                                          :end source-end)
                  do (if newline
                         (progn
                           (when (and target-line
                                      (eql line-index target-line))
                             (write-string source line-stream
                                           :start segment-start
                                           :end newline)
                             (return-from %visible-line-scan
                               (values
                                (get-output-stream-string line-stream)
                                line-count
                                t)))
                           (incf line-count)
                           (incf line-index)
                           (setf segment-start (1+ newline)))
                         (progn
                           (when (and target-line
                                      (eql line-index target-line))
                             (write-string source line-stream
                                           :start segment-start
                                           :end source-end))
                           (return))))))
        (setf cursor piece-end)))
    (values
     (when (and target-line
                (eql line-index target-line))
       (get-output-stream-string line-stream))
     line-count
     (and target-line
          (eql line-index target-line)))))

(defun %validate-narrow-region-order
    (start-line start-column end-line end-column)
  "Signal an error when END precedes START."
  (when (or (< end-line start-line)
            (and (= end-line start-line) (< end-column start-column)))
    (error "buffer-narrow-to-region: end position (~D,~D) precedes start position (~D,~D)"
           end-line end-column start-line start-column)))

(defun %clamp-offset-to-visible-region (buffer offset)
  "Clamp OFFSET into BUFFER's current visible region."
  (let ((visible-start (%buffer-narrow-start-offset buffer))
        (visible-end (%buffer-narrow-end-offset buffer)))
    (max visible-start
         (min offset visible-end))))

(defun %buffer-position-offset (buffer line column)
  "Return the absolute offset for LINE and COLUMN in BUFFER."
  (%position-to-offset buffer line column))

(defun %buffer-mark-offset (buffer)
  "Return mark's absolute offset, or NIL when mark is unset."
  (and (%buffer-mark-line buffer)
       (%buffer-position-offset buffer
                                (%buffer-mark-line buffer)
                                (%buffer-mark-column buffer))))

(defun %normalized-narrow-region-offsets
    (buffer start-line start-column end-line end-column)
  "Return narrowed START and END offsets normalized to BUFFER's visible region."
  (multiple-value-bind (normalized-start-line normalized-start-column)
      (%clamp-position buffer start-line start-column)
    (multiple-value-bind (normalized-end-line normalized-end-column)
        (%clamp-position buffer end-line end-column)
      (values (%clamp-offset-to-visible-region
               buffer
               (%buffer-position-offset buffer
                                        normalized-start-line
                                        normalized-start-column))
              (%clamp-offset-to-visible-region
               buffer
               (%buffer-position-offset buffer
                                        normalized-end-line
                                        normalized-end-column))))))

(defun %clamp-buffer-point-and-mark-to-visible-region
    (buffer point-offset mark-offset)
  "Clamp point and mark offsets into BUFFER's current visible region."
  (%set-buffer-point-from-offset
   buffer
   (%clamp-offset-to-visible-region buffer point-offset))
  (when mark-offset
    (%set-buffer-mark-from-offset
     buffer
     (%clamp-offset-to-visible-region buffer mark-offset))))
