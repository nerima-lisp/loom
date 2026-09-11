
(in-package #:loom)

(defun buffer-insert-string (buffer string)
  "Insert STRING into BUFFER at point, moving point to just after the
inserted text. Marks BUFFER as modified and records undo information.
Returns BUFFER."
  (%ensure-buffer-writable buffer)
  (unless (string= string "")
    (multiple-value-bind (end-line end-column)
        (%do-insert buffer (%buffer-point-line buffer) (%buffer-point-column buffer) string)
      (setf (%buffer-point-line buffer) end-line
            (%buffer-point-column buffer) end-column)))
  buffer)
