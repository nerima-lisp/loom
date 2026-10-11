
(in-package #:loom)

(defun buffer-insert-string (buffer string)
  "Insert nonempty STRING into BUFFER at point, moving point just after
the inserted text, marking BUFFER modified, and recording undo information.
An empty STRING leaves text, point, and history unchanged. Read-only BUFFER
signals BUFFER-READ-ONLY-ERROR even for an empty STRING. Returns BUFFER."
  (%ensure-buffer-writable buffer)
  (unless (string= string "")
    (multiple-value-bind (end-line end-column)
        (%do-insert buffer (%buffer-point-line buffer) (%buffer-point-column buffer) string)
      (setf (%buffer-point-line buffer) end-line
            (%buffer-point-column buffer) end-column)))
  buffer)
