(in-package #:loom)

;;; ---------------------------------------------------------------------
;;; Piece-table edit operations
;;;
;;; Representation stays in domain-buffer-storage.lisp. Position and line
;;; mapping live in domain-buffer-piece-table-position.lisp. Low-level
;;; splice/extraction helpers live in domain-buffer-piece-table-support.lisp.
;;; This file keeps the higher-level edit operations that update narrowing and
;;; undo/redo state; undo replay lives in domain-buffer-piece-table-undo.lisp.
;;; ---------------------------------------------------------------------

(defun %do-insert (buffer line column text &key (clear-redo t))
  "Insert TEXT at (LINE, COLUMN), mark BUFFER modified, and push an undo
entry describing the inverse of this exact edit (a delete of the same
span). Returns (values end-line end-column), the position just after the
inserted text.

When CLEAR-REDO is true, discard explicit redo history because this is a
new edit rather than an undo/redo replay."
  (%ensure-buffer-writable buffer)
  (let* ((was-narrowed (%buffer-narrowed-p buffer))
         (old-length (%buffer-full-length buffer))
         (text-length (length text)))
    (multiple-value-bind (end-line end-column) (%raw-insert-at buffer line column text)
      (if was-narrowed
          (incf (%buffer-narrow-end-offset buffer) text-length)
          (setf (%buffer-narrow-start-offset buffer) 0
                (%buffer-narrow-end-offset buffer) (+ old-length text-length)))
      (setf (%buffer-modified-p buffer) t)
      (when clear-redo
        (setf (%buffer-redo-list buffer) nil))
      (push (list :delete line column text) (%buffer-undo-list buffer))
      (values end-line end-column))))

(defun %do-delete (buffer start-line start-column end-line end-column
                   &key (clear-redo t))
  "Delete the region between the two positions, mark BUFFER modified, and
push an undo entry describing the inverse of this exact edit (a
re-insertion of the deleted text). Returns the deleted text.

When CLEAR-REDO is true, discard explicit redo history because this is a
new edit rather than an undo/redo replay."
  (%ensure-buffer-writable buffer)
  (let* ((start-offset (%position-to-offset buffer start-line start-column))
         (end-offset (%position-to-offset buffer end-line end-column))
         (text (%piece-table-range-text buffer start-offset end-offset))
         (was-narrowed (%buffer-narrowed-p buffer))
         (old-length (%buffer-full-length buffer))
         (deleted-length (- end-offset start-offset)))
    (%raw-delete-region buffer start-line start-column end-line end-column)
    (if was-narrowed
        (decf (%buffer-narrow-end-offset buffer) deleted-length)
        (setf (%buffer-narrow-start-offset buffer) 0
              (%buffer-narrow-end-offset buffer) (- old-length deleted-length)))
    (setf (%buffer-modified-p buffer) t)
    (when clear-redo
      (setf (%buffer-redo-list buffer) nil))
    (push (list :insert start-line start-column text) (%buffer-undo-list buffer))
    text))
