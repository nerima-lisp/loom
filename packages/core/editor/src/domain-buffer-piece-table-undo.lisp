(in-package #:loom)

;;; ---------------------------------------------------------------------
;;; Piece-table undo replay
;;;
;;; Core splice/mutation algorithms live in domain-buffer-piece-table.lisp.
;;; This file owns replaying recorded undo entries through those primitives.
;;; ---------------------------------------------------------------------

(defun %apply-undo-entry (buffer entry)
  "Apply ENTRY to BUFFER and return the inverse action it records.

The inverse is returned so BUFFER-UNDO can place it on the explicit redo
stack. Replay does not clear redo history; ordinary edits still do."
  (destructuring-bind (kind line column text) entry
    (ecase kind
      (:insert
       (multiple-value-bind (end-line end-column)
           (%do-insert buffer line column text :clear-redo nil)
         (setf (%buffer-point-line buffer) end-line
               (%buffer-point-column buffer) end-column))
       (list :delete line column text))
      (:delete
       (multiple-value-bind (end-line end-column) (%advance-position line column text)
         (%do-delete buffer line column end-line end-column
                     :clear-redo nil)
         (setf (%buffer-point-line buffer) line
               (%buffer-point-column buffer) column))
       (list :insert line column text)))))
