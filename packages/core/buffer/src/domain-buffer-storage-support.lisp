(in-package #:loom/core/buffer)


(defun %line-index-chunk (buffer line &optional create-p)
  (let ((node (%buffer-line-index buffer))
        (chunk (ash line (- +line-index-chunk-bits+))))
    (loop for depth downfrom (1- +line-index-directory-depth+) to 1
          for slot = (ldb (byte +line-index-directory-bits+
                               (* depth +line-index-directory-bits+)) chunk)
          do (setf node
                   (or (svref node slot)
                       (when create-p
                         (setf (svref node slot)
                               (make-array 32 :initial-element nil))))))
    (let ((slot (ldb (byte +line-index-directory-bits+ 0) chunk)))
      (or (svref node slot)
          (when create-p
            (setf (svref node slot)
                  (make-array (ceiling (* +line-index-chunk-size+
                                          +line-index-offset-bits+) 64)
                              :element-type '(unsigned-byte 64)
                              :initial-element 0)))))))

(defun %line-index-offset (buffer line)
  (let* ((words (%line-index-chunk buffer line))
         (bit (* (ldb (byte +line-index-chunk-bits+ 0) line)
                 +line-index-offset-bits+)))
    (declare (type (simple-array (unsigned-byte 64) (*)) words)
             (type fixnum bit))
    (multiple-value-bind (word shift) (floor bit 64)
      (let* ((low-width (min +line-index-offset-bits+ (- 64 shift)))
             (low (ldb (byte low-width shift) (aref words word))))
        (if (= low-width +line-index-offset-bits+)
            low
            (logior low
                    (ash (ldb (byte (- +line-index-offset-bits+ low-width) 0)
                              (aref words (1+ word)))
                         low-width)))))))

(defun (setf %line-index-offset) (value buffer line)
  (let* ((words (%line-index-chunk buffer line))
         (bit (* (ldb (byte +line-index-chunk-bits+ 0) line)
                 +line-index-offset-bits+)))
    (declare (type (simple-array (unsigned-byte 64) (*)) words)
             (type fixnum bit value))
    (multiple-value-bind (word shift) (floor bit 64)
      (let ((low-width (min +line-index-offset-bits+ (- 64 shift))))
        (setf (aref words word)
              (dpb value (byte low-width shift) (aref words word)))
        (unless (= low-width +line-index-offset-bits+)
          (setf (aref words (1+ word))
                (dpb (ash value (- low-width))
                     (byte (- +line-index-offset-bits+ low-width) 0)
                     (aref words (1+ word)))))))
    value))

(defun %release-line-index-chunk (buffer chunk)
  (labels ((release (node depth)
             (let ((slot (ldb (byte +line-index-directory-bits+
                                    (* depth +line-index-directory-bits+)) chunk)))
               (if (zerop depth)
                   (setf (svref node slot) nil)
                   (when (release (svref node slot) (1- depth))
                     (setf (svref node slot) nil))))
             (notany #'identity node)))
    (release (%buffer-line-index buffer) (1- +line-index-directory-depth+))))

(defun %resize-line-index (buffer old-count new-count)
  (let ((old-chunks (ceiling old-count +line-index-chunk-size+))
        (new-chunks (ceiling new-count +line-index-chunk-size+)))
    (loop for chunk from old-chunks below new-chunks
          do (%line-index-chunk buffer (* chunk +line-index-chunk-size+) t))
    (loop for chunk from new-chunks below old-chunks
          do (%release-line-index-chunk buffer chunk))))

(defun %initialize-line-index (buffer text)
  (%line-index-chunk buffer 0 t)
  (loop with line = 0
        for character across text
        for offset from 1
        when (char= character #\Newline)
          do (incf line)
             (%line-index-chunk buffer line t)
             (setf (%line-index-offset buffer line) offset)
        finally (setf (%buffer-line-count buffer) (1+ line)
                      (%buffer-text-length buffer) (length text)))
  buffer)

(defun %update-line-index-after-insert (buffer line offset text)
  (let* ((added (count #\Newline text))
         (old-count (%buffer-line-count buffer))
         (new-count (+ old-count added))
         (length (length text)))
    (%resize-line-index buffer old-count new-count)
    (loop for old-line downfrom (1- old-count) above line
          do (setf (%line-index-offset buffer (+ old-line added))
                   (+ (%line-index-offset buffer old-line) length)))
    (loop with new-line = line
          for character across text
          for position from (1+ offset)
          when (char= character #\Newline)
            do (incf new-line)
               (setf (%line-index-offset buffer new-line) position))
    (setf (%buffer-line-count buffer) new-count)
    (incf (%buffer-text-length buffer) length)))

(defun %update-line-index-after-delete (buffer start-line end-line length)
  (let* ((removed (- end-line start-line))
         (old-count (%buffer-line-count buffer))
         (new-count (- old-count removed)))
    (loop for old-line from (1+ end-line) below old-count
          do (setf (%line-index-offset buffer (- old-line removed))
                   (- (%line-index-offset buffer old-line) length)))
    (%resize-line-index buffer old-count new-count)
    (setf (%buffer-line-count buffer) new-count)
    (decf (%buffer-text-length buffer) length)))

(defun %record-buffer-change (buffer line)
  (incf (%buffer-version buffer))
  (setf (aref (%buffer-changed-lines buffer)
              (mod (%buffer-version buffer) +buffer-change-history-size+))
        line))


(defun %piece-source-text (buffer piece)
  (ecase (%piece-source piece)
    (:original (%buffer-original buffer))
    (:add (%buffer-add-buffer buffer))))

(defun %piece-text (buffer piece)
  (let ((source (%piece-source-text buffer piece)))
    (subseq source
            (%piece-start piece)
            (+ (%piece-start piece) (%piece-length piece)))))

(defun %pieces-text (buffer)
  (with-output-to-string (stream)
    (dolist (piece (%buffer-pieces buffer))
      (write-string (%piece-text buffer piece) stream))))
