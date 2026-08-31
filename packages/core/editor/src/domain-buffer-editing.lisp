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
  (unless (zerop (length string))
    (multiple-value-bind (end-line end-column)
        (%do-insert buffer (%buffer-point-line buffer) (%buffer-point-column buffer) string)
      (setf (%buffer-point-line buffer) end-line
            (%buffer-point-column buffer) end-column)))
  buffer)

(defun %delete-char-backward (buffer)
  "Delete the character before point, joining with the previous line at
column 0. A no-op at the very start of the buffer."
  (let ((line (%buffer-point-line buffer))
        (column (%buffer-point-column buffer)))
    (cond
      ((and (zerop line) (zerop column)) nil)
      ((plusp column)
       (%do-delete buffer line (1- column) line column)
       (setf (%buffer-point-line buffer) line
             (%buffer-point-column buffer) (1- column)))
      (t
       (let* ((prev-line (1- line))
              (prev-len (length (%line-at buffer prev-line))))
         (%do-delete buffer prev-line prev-len line 0)
         (setf (%buffer-point-line buffer) prev-line
               (%buffer-point-column buffer) prev-len))))))

(defun %delete-char-forward (buffer)
  "Delete the character at point, joining with the next line at
end-of-line. A no-op at the very end of the buffer."
  (let* ((line (%buffer-point-line buffer))
         (column (%buffer-point-column buffer))
         (line-count (%line-count buffer))
         (line-len (length (%line-at buffer line))))
    (cond
      ((and (= line (1- line-count)) (= column line-len)) nil)
      ((< column line-len) (%do-delete buffer line column line (1+ column)))
      (t (%do-delete buffer line column (1+ line) 0)))))

(defun buffer-delete-char (buffer &key backward)
  "Delete one character next to point, returning BUFFER."
  (%ensure-buffer-writable buffer)
  (let ((point-offset (buffer-point-offset buffer)))
    (if backward
        (unless (<= point-offset (%buffer-narrow-start-offset buffer))
          (%delete-char-backward buffer))
        (unless (>= point-offset (%buffer-narrow-end-offset buffer))
          (%delete-char-forward buffer))))
  buffer)

(defun buffer-delete-region (buffer start-line start-column end-line end-column)
  "Delete the text between the zero-based (START-LINE, START-COLUMN) and
(END-LINE, END-COLUMN) positions (end exclusive). The end position must not
precede the start position. Moves point to the start position. Marks BUFFER
as modified and records undo information. Returns the deleted text as a
string."
  (when (or (< end-line start-line)
              (and (= end-line start-line) (< end-column start-column)))
      (error "buffer-delete-region: end position (~D,~D) precedes start position (~D,~D)"
             end-line end-column start-line start-column))
    (%ensure-buffer-writable buffer)
    (multiple-value-bind (start-offset end-offset)
        (%region-offsets-within-narrowing
         buffer start-line start-column end-line end-column)
      (if (= start-offset end-offset)
          ""
          (multiple-value-bind (normalized-start-line normalized-start-column)
              (%offset-to-position-values buffer start-offset)
            (multiple-value-bind (normalized-end-line normalized-end-column)
                (%offset-to-position-values buffer end-offset)
              (let ((text
                      (%do-delete buffer
                                  normalized-start-line normalized-start-column
                                  normalized-end-line normalized-end-column)))
                (%set-buffer-point-from-offset buffer start-offset)
                text))))))
