;;;; packages/core/editor/src/domain-buffer-accessors.lisp
;;;;
;;;; Domain layer: line/point/mark/region query APIs layered on top of the
;;;; core buffer protocol in domain-buffer.lisp. Representation and
;;;; piece-table mutation primitives stay in domain-buffer-storage.lisp and
;;;; domain-buffer-piece-table.lisp; this file owns the public position-aware
;;;; read/query operations and shared point/mark offset helpers.

(in-package #:loom)

(defun %clamp-offset-to-narrowing (buffer offset)
  (max (%buffer-narrow-start-offset buffer)
       (min offset (%buffer-narrow-end-offset buffer))))

(defun %region-offsets-within-narrowing
    (buffer start-line start-column end-line end-column)
  (values
   (%clamp-offset-to-narrowing
    buffer
    (%position-to-offset buffer start-line start-column))
   (%clamp-offset-to-narrowing
    buffer
    (%position-to-offset buffer end-line end-column))))

(defun %set-buffer-point-from-offset (buffer offset)
  (multiple-value-bind (line column)
      (%offset-to-position-values buffer offset)
    (setf (%buffer-point-line buffer) line
          (%buffer-point-column buffer) column)))

(defun %set-buffer-mark-from-offset (buffer offset)
  (multiple-value-bind (line column)
      (%offset-to-position-values buffer offset)
    (setf (%buffer-mark-line buffer) line
          (%buffer-mark-column buffer) column)))

(defun buffer-line-count (buffer)
  "Return the number of lines in BUFFER; an empty buffer has one line."
  (%line-count buffer))

(defun buffer-line (buffer line-number)
  "Return the zero-based LINE-NUMBER text without its trailing newline."
  (unless (and (>= line-number 0) (< line-number (%line-count buffer)))
    (error "buffer-line: line-number ~D out of range [0,~D)" line-number (%line-count buffer)))
  (%line-at buffer line-number))

(defun buffer-point-line (buffer)
  "Return the zero-based line number of BUFFER's point."
  (%buffer-point-line buffer))

(defun buffer-point-column (buffer)
  "Return the zero-based column (in characters, not display width) of
BUFFER's point on its current line."
  (%buffer-point-column buffer))

(defun buffer-set-point (buffer line column)
  "Move BUFFER's point to the zero-based (LINE, COLUMN) position, clamping
or signalling an error on an out-of-range position at the implementation's
discretion. Returns BUFFER."
  (multiple-value-bind (clamped-line clamped-column) (%clamp-position buffer line column)
    (let ((offset
            (%clamp-offset-to-narrowing
             buffer
             (%position-to-offset buffer clamped-line clamped-column))))
      (%set-buffer-point-from-offset buffer offset)))
  buffer)

(defun buffer-mark (buffer)
  "Return the position of BUFFER's mark as (VALUES LINE COLUMN), both
zero-based, or (VALUES NIL NIL) if no mark is currently set."
  (values (%buffer-mark-line buffer) (%buffer-mark-column buffer)))

(defun buffer-set-mark (buffer line column)
  "Set BUFFER's mark to the zero-based (LINE, COLUMN) position. Returns
BUFFER."
  (multiple-value-bind (clamped-line clamped-column) (%clamp-position buffer line column)
    (let ((offset
            (%clamp-offset-to-narrowing
             buffer
             (%position-to-offset buffer clamped-line clamped-column))))
      (%set-buffer-mark-from-offset buffer offset)))
  buffer)

(defun buffer-region-string (buffer start-line start-column end-line end-column)
  "Return, without modifying BUFFER, the text between the zero-based
(START-LINE, START-COLUMN) and (END-LINE, END-COLUMN) positions (end
exclusive), as a string."
  (when (or (< end-line start-line)
            (and (= end-line start-line) (< end-column start-column)))
    (error "buffer-region-string: end position (~D,~D) precedes start position (~D,~D)"
           end-line end-column start-line start-column))
  (multiple-value-bind (start-offset end-offset)
      (%region-offsets-within-narrowing
       buffer start-line start-column end-line end-column)
    (%piece-table-range-text buffer start-offset end-offset)))
