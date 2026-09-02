;;;; packages/core/editor/src/domain-buffer-deletion.lisp
;;;;
;;;; Domain layer: deletion APIs and their point/range coordination.

(in-package #:loom)

(defun %backward-delete-line (line column)
  (cond
    ((and (zerop line) (zerop column)) nil)
    ((plusp column) line)
    (t (1- line))))

(defun %delete-backward-within-line (buffer line column)
  (%do-delete buffer line (1- column) line column)
  (setf (%buffer-point-line buffer) line
        (%buffer-point-column buffer) (1- column)))

(defun %delete-backward-across-line (buffer line)
  (let* ((previous-line (1- line))
         (previous-length (length (%line-at buffer previous-line))))
    (%do-delete buffer previous-line previous-length line 0)
    (setf (%buffer-point-line buffer) previous-line
          (%buffer-point-column buffer) previous-length)))

(defun %forward-delete-end-position (line column line-count line-length)
  (cond
    ((and (= line (1- line-count)) (= column line-length)) nil)
    ((< column line-length) (values line (1+ column)))
    (t (values (1+ line) 0))))

(defun %delete-char-backward (buffer)
  "Delete the character before point, joining with the previous line at
column 0. A no-op at the very start of the buffer."
  (let ((line (%buffer-point-line buffer))
        (column (%buffer-point-column buffer)))
    (let ((previous-line (%backward-delete-line line column)))
      (cond
        ((null previous-line) nil)
        ((= previous-line line)
         (%delete-backward-within-line buffer line column))
        (t
         (%delete-backward-across-line buffer line))))))

(defun %delete-char-forward (buffer)
  "Delete the character at point, joining with the next line at
end-of-line. A no-op at the very end of the buffer."
  (let* ((line (%buffer-point-line buffer))
         (column (%buffer-point-column buffer))
         (line-count (%line-count buffer))
         (line-len (length (%line-at buffer line))))
    (multiple-value-bind (end-line end-column)
        (%forward-delete-end-position line column line-count line-len)
      (when end-line
        (%do-delete buffer line column end-line end-column)))))

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

(defun %delete-region-at-offsets (buffer start-offset end-offset)
  (multiple-value-bind (start-line start-column)
      (%offset-to-position-values buffer start-offset)
    (multiple-value-bind (end-line end-column)
        (%offset-to-position-values buffer end-offset)
      (let ((text (%do-delete buffer start-line start-column end-line end-column)))
        (%set-buffer-point-from-offset buffer start-offset)
        text))))

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
        (%delete-region-at-offsets buffer start-offset end-offset))))
