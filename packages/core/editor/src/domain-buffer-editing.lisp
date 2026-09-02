;;;; packages/core/editor/src/domain-buffer-editing.lisp
;;;;
;;;; Domain layer: text mutation APIs layered on top of the core buffer
;;;; protocol in domain-buffer.lisp. Query/accessor operations live in
;;;; domain-buffer-accessors.lisp; representation and piece-table mutation
;;;; primitives stay in domain-buffer-storage.lisp and
;;;; domain-buffer-piece-table.lisp.

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
