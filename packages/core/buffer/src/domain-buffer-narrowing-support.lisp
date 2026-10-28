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
(defun %visible-lines-scan (buffer start-line line-limit)
  "Return visible lines starting at START-LINE and their total count in one scan."
  (check-type start-line (integer 0 *))
  (check-type line-limit (integer 0 *))
  (let* ((visible-start (%buffer-narrow-start-offset buffer))
         (visible-end (%buffer-narrow-end-offset buffer))
         (requested-end (+ start-line line-limit))
         (cursor 0)
         (line-index 0)
         (line-count 1)
         (line-stream
           (when (and (zerop start-line) (plusp line-limit))
             (make-string-output-stream)))
         (lines nil))
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
                           (when line-stream
                             (write-string source line-stream
                                           :start segment-start
                                           :end newline)
                             (push (get-output-stream-string line-stream) lines)
                             (setf line-stream nil))
                           (incf line-count)
                           (incf line-index)
                           (when (and (>= line-index start-line)
                                      (< line-index requested-end))
                             (setf line-stream (make-string-output-stream)))
                           (setf segment-start (1+ newline)))
                         (progn
                           (when line-stream
                             (write-string source line-stream
                                           :start segment-start
                                           :end source-end))
                           (return))))))
        (setf cursor piece-end)))
    (when line-stream
      (push (get-output-stream-string line-stream) lines))
    (values (nreverse lines) line-count)))
(progn
  (defvar *buffer-visible-line-index-cache* nil)
  (defmacro with-buffer-visible-line-index-cache (&body body)
    `(let ((*buffer-visible-line-index-cache* (make-hash-table :test 'eq)))
       ,@body))
  (defstruct (%visible-line-index
              (:constructor %make-visible-line-index
                  (&key line-starts visible-length segment-starts
                        segment-source-starts segment-sources pieces
                        narrow-start narrow-end original add-buffer
                        add-buffer-length line-cache)))
    (line-starts #() :type vector)
    (visible-length 0 :type fixnum)
    (segment-starts #() :type vector)
    (segment-source-starts #() :type vector)
    (segment-sources #() :type vector)
    (pieces nil)
    (narrow-start 0 :type fixnum)
    (narrow-end 0 :type fixnum)
    (original nil)
    (add-buffer nil)
    (add-buffer-length 0 :type fixnum)
    (line-cache nil :type hash-table))
  (defun %build-visible-line-index (buffer)
    (let* ((pieces (%buffer-pieces buffer))
           (visible-start (%buffer-narrow-start-offset buffer))
           (visible-end (%buffer-narrow-end-offset buffer))
           (line-starts (make-array 16 :element-type 'fixnum
                                    :adjustable t :fill-pointer 0))
           (segment-starts (make-array 8 :element-type 'fixnum
                                      :adjustable t :fill-pointer 0))
           (segment-source-starts (make-array 8 :element-type 'fixnum
                                              :adjustable t :fill-pointer 0))
           (segment-sources (make-array 8 :adjustable t :fill-pointer 0))
           (cursor 0))
      (vector-push-extend 0 line-starts)
      (dolist (piece pieces)
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
                     (+ (%piece-start piece) (- visible-piece-end cursor)))
                   (logical-start (- visible-piece-start visible-start)))
              (vector-push-extend logical-start segment-starts)
              (vector-push-extend source-start segment-source-starts)
              (vector-push-extend source segment-sources)
              (loop with segment-start = source-start
                    for newline = (position #\Newline source
                                            :start segment-start
                                            :end source-end)
                    while newline
                    do (vector-push-extend
                        (+ logical-start (1+ (- newline source-start)))
                        line-starts)
                       (setf segment-start (1+ newline)))))
          (setf cursor piece-end)))
      (%make-visible-line-index
       :line-starts line-starts
       :visible-length (- visible-end visible-start)
       :segment-starts segment-starts
       :segment-source-starts segment-source-starts
       :segment-sources segment-sources
       :pieces pieces
       :narrow-start visible-start
       :narrow-end visible-end
       :original (%buffer-original buffer)
       :add-buffer (%buffer-add-buffer buffer)
       :add-buffer-length (fill-pointer (%buffer-add-buffer buffer))
       :line-cache (make-hash-table :test 'eql))))
  (defun %visible-line-index-current-p (buffer index)
    (and (eq (%visible-line-index-pieces index) (%buffer-pieces buffer))
         (= (%visible-line-index-narrow-start index)
            (%buffer-narrow-start-offset buffer))
         (= (%visible-line-index-narrow-end index)
            (%buffer-narrow-end-offset buffer))
         (eq (%visible-line-index-original index) (%buffer-original buffer))
         (eq (%visible-line-index-add-buffer index) (%buffer-add-buffer buffer))
         (= (%visible-line-index-add-buffer-length index)
            (fill-pointer (%buffer-add-buffer buffer)))))
  (defun %buffer-visible-line-index (buffer)
    (when *buffer-visible-line-index-cache*
      (multiple-value-bind (index present-p)
          (gethash buffer *buffer-visible-line-index-cache*)
        (if (and present-p (%visible-line-index-current-p buffer index))
            index
            (setf (gethash buffer *buffer-visible-line-index-cache*)
                  (%build-visible-line-index buffer))))))
  (defun %visible-line-index-segment (index offset)
    (let ((starts (%visible-line-index-segment-starts index))
          (low 0)
          (high (length (%visible-line-index-segment-starts index))))
      (loop while (< low high)
            for middle = (floor (+ low high) 2)
            do (if (<= (aref starts middle) offset)
                   (setf low (1+ middle))
                   (setf high middle)))
      (1- low)))
  (defun %visible-line-index-materialize-line (index start end)
    (if (= start end)
        ""
        (let ((segment-index (%visible-line-index-segment index start))
              (position start)
              (segment-starts (%visible-line-index-segment-starts index))
              (source-starts
                (%visible-line-index-segment-source-starts index))
              (sources (%visible-line-index-segment-sources index))
              (visible-length (%visible-line-index-visible-length index))
              (parts nil))
          (loop while (< position end)
                do (let* ((segment-start (aref segment-starts segment-index))
                          (segment-end
                            (if (< (1+ segment-index) (length segment-starts))
                                (aref segment-starts (1+ segment-index))
                                visible-length))
                          (slice-end (min end segment-end))
                          (source-offset
                            (+ (aref source-starts segment-index)
                               (- position segment-start))))
                     (push (subseq
                            (aref sources segment-index)
                            source-offset
                            (+ source-offset (- slice-end position)))
                           parts)
                     (setf position slice-end)
                     (when (< position end)
                       (incf segment-index))))
          (if (cdr parts)
              (apply #'concatenate 'string (nreverse parts))
              (first parts)))))
  (defun %visible-line-index-line (index line-number)
    (let* ((line-starts (%visible-line-index-line-starts index))
           (line-count (length line-starts)))
      (if (or (< line-number 0) (>= line-number line-count))
          (values nil nil)
          (multiple-value-bind (line present-p)
              (gethash line-number (%visible-line-index-line-cache index))
            (if present-p
                (values line t)
                (let* ((start (aref line-starts line-number))
                       (end
                         (if (< (1+ line-number) line-count)
                             (1- (aref line-starts (1+ line-number)))
                             (%visible-line-index-visible-length index)))
                       (line
                         (%visible-line-index-materialize-line index start end)))
                  (setf (gethash line-number
                                 (%visible-line-index-line-cache index))
                        line)
                  (values line t)))))))
  (defun %visible-line-index-lines (index start-line line-limit)
    (check-type start-line (integer 0 *))
    (check-type line-limit (integer 0 *))
    (let* ((line-count (length (%visible-line-index-line-starts index)))
           (end-line (min line-count (+ start-line line-limit)))
           (lines nil))
      (loop for line-number from start-line below end-line
            do (push (nth-value 0 (%visible-line-index-line index line-number))
                     lines))
      (values (nreverse lines) line-count))))
