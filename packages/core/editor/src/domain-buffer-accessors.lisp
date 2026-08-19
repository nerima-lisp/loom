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

(defgeneric buffer-line-count (buffer)
  (:documentation "Return the number of lines in BUFFER; an empty buffer has one line.")
  (:method (buffer)
    (%line-count buffer)))

(defgeneric buffer-line (buffer line-number)
  (:documentation "Return the zero-based LINE-NUMBER text without its trailing newline.")
  (:method (buffer line-number)
    (unless (and (>= line-number 0) (< line-number (%line-count buffer)))
      (error "buffer-line: line-number ~D out of range [0,~D)" line-number (%line-count buffer)))
    (%line-at buffer line-number)))

(defgeneric buffer-point-line (buffer)
  (:documentation "Return the zero-based line number of BUFFER's point.")
  (:method (buffer)
    (%buffer-point-line buffer)))

(defgeneric buffer-point-column (buffer)
  (:documentation
   "Return the zero-based column (in characters, not display width) of
BUFFER's point on its current line.")
  (:method (buffer)
    (%buffer-point-column buffer)))

(defgeneric buffer-set-point (buffer line column)
  (:documentation
   "Move BUFFER's point to the zero-based (LINE, COLUMN) position, clamping
or signalling an error on an out-of-range position at the implementation's
discretion. Returns BUFFER.")
  (:method (buffer line column)
    (multiple-value-bind (clamped-line clamped-column) (%clamp-position buffer line column)
      (let ((offset
              (%clamp-offset-to-narrowing
               buffer
               (%position-to-offset buffer clamped-line clamped-column))))
        (%set-buffer-point-from-offset buffer offset)))
    buffer))

(defgeneric buffer-mark (buffer)
  (:documentation
   "Return the position of BUFFER's mark as (VALUES LINE COLUMN), both
zero-based, or (VALUES NIL NIL) if no mark is currently set.")
  (:method (buffer)
    (values (%buffer-mark-line buffer) (%buffer-mark-column buffer))))

(defgeneric buffer-set-mark (buffer line column)
  (:documentation
   "Set BUFFER's mark to the zero-based (LINE, COLUMN) position. Returns
BUFFER.")
  (:method (buffer line column)
    (multiple-value-bind (clamped-line clamped-column) (%clamp-position buffer line column)
      (let ((offset
              (%clamp-offset-to-narrowing
               buffer
               (%position-to-offset buffer clamped-line clamped-column))))
        (%set-buffer-mark-from-offset buffer offset)))
    buffer))

(defgeneric buffer-region-string (buffer start-line start-column end-line end-column)
  (:documentation
   "Return, without modifying BUFFER, the text between the zero-based
(START-LINE, START-COLUMN) and (END-LINE, END-COLUMN) positions (end
exclusive), as a string.")
  (:method (buffer start-line start-column end-line end-column)
    (when (or (< end-line start-line)
              (and (= end-line start-line) (< end-column start-column)))
      (error "buffer-region-string: end position (~D,~D) precedes start position (~D,~D)"
             end-line end-column start-line start-column))
    (multiple-value-bind (start-offset end-offset)
        (%region-offsets-within-narrowing
         buffer start-line start-column end-line end-column)
      (%piece-table-range-text buffer start-offset end-offset))))
