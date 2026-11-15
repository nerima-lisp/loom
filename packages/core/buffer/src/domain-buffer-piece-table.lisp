(in-package #:loom/core/buffer)


(defun %update-after-insert (buffer was-narrowed-p old-length offset text-length)
  (if was-narrowed-p
      (progn
        ;; Both boundaries include insertion exactly at their position.
        (when (< offset (%buffer-narrow-start-offset buffer))
          (incf (%buffer-narrow-start-offset buffer) text-length))
        (when (<= offset (%buffer-narrow-end-offset buffer))
          (incf (%buffer-narrow-end-offset buffer) text-length)))
      (setf (%buffer-narrow-start-offset buffer) 0
            (%buffer-narrow-end-offset buffer) (+ old-length text-length)))
  (setf (%buffer-modified-p buffer) t))

(defun %record-insert (buffer line column text clear-redo
                       &optional undo-replacement-p)
  (when clear-redo
    (setf (%buffer-redo-list buffer) nil
          (%buffer-undo-continuation-count buffer) 0))
  (push (append
         (list :delete line column text
               (%buffer-point-line buffer)
               (%buffer-point-column buffer))
         (when undo-replacement-p (list :undo-replacement)))
        (%buffer-undo-list buffer)))

(defun %update-after-delete (buffer was-narrowed-p old-length offset deleted-length)
  (if was-narrowed-p
      (setf (%buffer-narrow-start-offset buffer)
            (- (%buffer-narrow-start-offset buffer)
               (min deleted-length
                    (max 0 (- (%buffer-narrow-start-offset buffer) offset))))
            (%buffer-narrow-end-offset buffer)
            (- (%buffer-narrow-end-offset buffer)
               (min deleted-length
                    (max 0 (- (%buffer-narrow-end-offset buffer) offset)))))
      (setf (%buffer-narrow-start-offset buffer) 0
            (%buffer-narrow-end-offset buffer) (- old-length deleted-length)))
  (setf (%buffer-modified-p buffer) t))

(defun %record-delete (buffer line column text clear-redo
                       &optional undo-replacement-p)
  (when clear-redo
    (setf (%buffer-redo-list buffer) nil
          (%buffer-undo-continuation-count buffer) 0))
  (multiple-value-bind (end-line end-column)
      (%advance-position line column text)
    (push (append
           (list :insert line column text
                 (%buffer-point-line buffer)
                 (%buffer-point-column buffer)
                 (and (= (%buffer-point-line buffer) end-line)
                      (= (%buffer-point-column buffer) end-column)))
           (when undo-replacement-p (list :undo-replacement)))
          (%buffer-undo-list buffer))))

(defun %do-insert (buffer line column text &key (clear-redo t)
                                undo-replacement-p)
  "Insert TEXT at (LINE, COLUMN), mark BUFFER modified, and push an undo
entry describing the inverse of this exact edit (a delete of the same
span). Returns (values end-line end-column), the position just after the
inserted text.

When CLEAR-REDO is true, discard explicit redo history because this is a
new edit rather than an undo/redo replay."
  (%ensure-buffer-writable buffer)
  (sb-sys:without-interrupts
    (let* ((was-narrowed (%buffer-narrowed-p buffer))
           (old-length (%buffer-full-length buffer))
           (text-length (length text))
           (offset (%position-to-offset buffer line column)))
      (multiple-value-bind (end-line end-column)
          (%raw-insert-at buffer line column text)
        (%update-line-index-after-insert buffer line offset text)
        (%update-after-insert buffer was-narrowed old-length offset text-length)
        (%record-insert buffer line column text clear-redo undo-replacement-p)
        (%record-buffer-change buffer line)
        (values end-line end-column)))))

(defun %do-delete (buffer start-line start-column end-line end-column
                   &key (clear-redo t) undo-replacement-p)
  "Delete the region between the two positions, mark BUFFER modified, and
push an undo entry describing the inverse of this exact edit (a
re-insertion of the deleted text). Returns the deleted text.

When CLEAR-REDO is true, discard explicit redo history because this is a
new edit rather than an undo/redo replay."
  (%ensure-buffer-writable buffer)
  (sb-sys:without-interrupts
    (let* ((start-offset (%position-to-offset buffer start-line start-column))
           (end-offset (%position-to-offset buffer end-line end-column))
           (text (%piece-table-range-text buffer start-offset end-offset))
           (was-narrowed (%buffer-narrowed-p buffer))
           (old-length (%buffer-full-length buffer))
           (deleted-length (- end-offset start-offset)))
      (%raw-delete-region buffer start-line start-column end-line end-column)
      (%update-line-index-after-delete buffer start-line end-line deleted-length)
      (%update-after-delete buffer was-narrowed old-length start-offset deleted-length)
      (%record-delete buffer start-line start-column text clear-redo undo-replacement-p)
      (%record-buffer-change buffer start-line)
      text)))
