(in-package #:loom/core/buffer)


(defun %replay-insert-entry
    (buffer line column text
     &optional point-at-deletion-end-p affinity-p undo-replacement-p)
  (multiple-value-bind (end-line end-column)
      (%do-insert buffer line column text
                  :clear-redo nil
                  :undo-replacement-p undo-replacement-p)
    (if (and affinity-p (not point-at-deletion-end-p))
        (setf (%buffer-point-line buffer) line
              (%buffer-point-column buffer) column)
        (setf (%buffer-point-line buffer) end-line
              (%buffer-point-column buffer) end-column)))
  (list :delete line column text))

(defun %replay-delete-entry
    (buffer line column text
     &optional point-at-deletion-end-p affinity-p undo-replacement-p)
  (multiple-value-bind (end-line end-column)
      (%advance-position line column text)
    (%do-delete buffer line column end-line end-column
                :clear-redo nil
                :undo-replacement-p undo-replacement-p)
    (when affinity-p
      (setf (seventh (car (%buffer-undo-list buffer)))
            point-at-deletion-end-p))
    (setf (%buffer-point-line buffer) line
          (%buffer-point-column buffer) column))
  (list :insert line column text))

(defun %apply-undo-entry (buffer entry &optional (restore-point-p t))
  "Apply ENTRY to BUFFER and return the inverse action. When RESTORE-POINT-P
is nil, keep the point established by the replayed insertion unless ENTRY
marks a replacement whose original point must be restored."
  (destructuring-bind
      (kind line column text point-line point-column &rest metadata)
      entry
    (let* ((affinity-p
             (and metadata
                  (not (eq (first metadata) :undo-replacement))))
           (point-at-deletion-end-p
             (when affinity-p (first metadata)))
           (undo-replacement-p (member :undo-replacement metadata))
           (redo-line (%buffer-point-line buffer))
           (redo-column (%buffer-point-column buffer)))
      (let ((inverse
              (ecase kind
                (:insert (%replay-insert-entry
                          buffer line column text
                          point-at-deletion-end-p affinity-p
                          undo-replacement-p))
                (:delete (%replay-delete-entry
                          buffer line column text
                          point-at-deletion-end-p affinity-p
                          undo-replacement-p)))))
        (when (or restore-point-p undo-replacement-p)
          (multiple-value-bind (clamped-line clamped-column)
              (%clamp-position buffer point-line point-column)
            (let ((offset
                    (max (%buffer-narrow-start-offset buffer)
                         (min (%position-to-offset buffer clamped-line clamped-column)
                              (%buffer-narrow-end-offset buffer)))))
              (multiple-value-bind (restored-line restored-column)
                  (%offset-to-position-values buffer offset)
                (setf (%buffer-point-line buffer) restored-line
                      (%buffer-point-column buffer) restored-column)))))
        (append inverse
                (list redo-line redo-column)
                (when affinity-p (list point-at-deletion-end-p))
                (when undo-replacement-p (list :undo-replacement)))))))
