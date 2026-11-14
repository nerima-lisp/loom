(in-package #:loom/core/buffer)

(defvar *buffer-visible-line-index-cache* nil)

(defmacro with-buffer-visible-line-index-cache (&body body)
  `(let ((*buffer-visible-line-index-cache* (make-hash-table :test 'eq)))
     ,@body))

(defstruct (%buffer-visible-view (:constructor %make-buffer-visible-view))
  (version 0 :type integer)
  (start 0 :type fixnum)
  (end 0 :type fixnum)
  (first-line 0 :type fixnum)
  (last-line 0 :type fixnum)
  (lines (make-hash-table :test 'eql) :type hash-table))

(defun %buffer-narrow-start-line (buffer)
  (let ((start (%buffer-narrow-start-offset buffer)))
    (if (zerop start) 0 (nth-value 0 (%offset-to-position-values buffer start)))))

(defun %build-buffer-visible-view (buffer)
  (let ((end (%buffer-narrow-end-offset buffer)))
    (%make-buffer-visible-view
     :version (%buffer-version buffer)
     :start (%buffer-narrow-start-offset buffer)
     :end end
     :first-line (%buffer-narrow-start-line buffer)
     :last-line (if (= end (%buffer-text-length buffer))
                    (1- (%buffer-line-count buffer))
                    (nth-value 0 (%offset-to-position-values buffer end))))))

(defun %buffer-visible-view-current-p (buffer view)
  (and (= (%buffer-visible-view-version view) (%buffer-version buffer))
       (= (%buffer-visible-view-start view) (%buffer-narrow-start-offset buffer))
       (= (%buffer-visible-view-end view) (%buffer-narrow-end-offset buffer))))

(defun %current-buffer-visible-view (buffer)
  (if *buffer-visible-line-index-cache*
      (let ((view (gethash buffer *buffer-visible-line-index-cache*)))
        (if (and view (%buffer-visible-view-current-p buffer view))
            view
            (setf (gethash buffer *buffer-visible-line-index-cache*)
                  (%build-buffer-visible-view buffer))))
      (%build-buffer-visible-view buffer)))

(defun %buffer-visible-view-line-count (view)
  (1+ (- (%buffer-visible-view-last-line view)
         (%buffer-visible-view-first-line view))))

(defun %buffer-visible-view-line (buffer view line)
  (multiple-value-bind (text present-p)
      (gethash line (%buffer-visible-view-lines view))
    (if present-p
        text
        (let* ((absolute-line (+ (%buffer-visible-view-first-line view) line))
               (start (if (zerop line)
                          (%buffer-visible-view-start view)
                          (%line-index-offset buffer absolute-line)))
               (end (min (%buffer-visible-view-end view)
                         (if (< (1+ absolute-line) (%buffer-line-count buffer))
                             (1- (%line-index-offset buffer (1+ absolute-line)))
                             (%buffer-text-length buffer))))
               (text (%piece-table-range-text buffer start end)))
          (setf (gethash line (%buffer-visible-view-lines view)) text)))))

(defun %visible-offset-to-position-values (buffer offset)
  (multiple-value-bind (line column) (%offset-to-position-values buffer offset)
    (let ((first-line (%buffer-narrow-start-line buffer)))
      (values (- line first-line)
              (if (= line first-line)
                  (- column (- (%buffer-narrow-start-offset buffer)
                               (%line-index-offset buffer first-line)))
                  column)))))

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


