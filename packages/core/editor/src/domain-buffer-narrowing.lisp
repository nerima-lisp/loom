;;;; packages/core/editor/src/domain-buffer-narrowing.lisp
;;;;
;;;; Domain layer: visible-region queries and narrowing APIs layered on top of
;;;; the core buffer protocol in domain-buffer.lisp.
(in-package #:loom)

(defun buffer-narrow-start-offset (buffer)
  "Return the absolute, inclusive start offset of BUFFER's visible region."
  (%buffer-narrow-start-offset buffer))

(defun buffer-narrow-end-offset (buffer)
  "Return the absolute, exclusive end offset of BUFFER's visible region."
  (%buffer-narrow-end-offset buffer))

(defun buffer-narrowed-p (buffer)
  "Return true when BUFFER is displaying a narrowed region."
  (%buffer-narrowed-p buffer))

(defun buffer-visible-text (buffer)
  "Return the text in BUFFER's current visible region, excluding hidden text."
  (subseq (buffer-text buffer)
          (%buffer-narrow-start-offset buffer)
          (%buffer-narrow-end-offset buffer)))

(defun buffer-visible-line-count (buffer)
  "Return the number of lines in BUFFER's visible region."
  (length (%visible-lines buffer)))

(defun buffer-visible-line (buffer line-number)
  "Return the zero-based LINE-NUMBER text in BUFFER's visible region."
  (let ((lines (%visible-lines buffer)))
    (unless (and (>= line-number 0) (< line-number (length lines)))
      (error "buffer-visible-line: line-number ~D out of range [0,~D)"
             line-number (length lines)))
    (nth line-number lines)))

(defun buffer-visible-point-line (buffer)
  "Return point's zero-based line within BUFFER's visible region."
  (multiple-value-bind (line column)
      (%text-offset-to-position-values
       (buffer-visible-text buffer)
       (- (buffer-point-offset buffer) (%buffer-narrow-start-offset buffer)))
    (declare (ignore column))
    line))

(defun buffer-visible-point-column (buffer)
  "Return point's zero-based column within BUFFER's visible region."
  (multiple-value-bind (line column)
      (%text-offset-to-position-values
       (buffer-visible-text buffer)
       (- (buffer-point-offset buffer) (%buffer-narrow-start-offset buffer)))
    (declare (ignore line))
    column))

(defun buffer-narrow-to-region
    (buffer start-line start-column end-line end-column)
  "Limit BUFFER's visible and editable region to the half-open region
between the two zero-based positions. Point and mark are clamped into the
new region. Returns BUFFER."
  (%validate-narrow-region-order
   start-line start-column end-line end-column)
  (let ((point-offset
          (%buffer-position-offset buffer
                                   (%buffer-point-line buffer)
                                   (%buffer-point-column buffer)))
        (mark-offset (%buffer-mark-offset buffer)))
    (multiple-value-bind (start-offset end-offset)
        (%normalized-narrow-region-offsets
         buffer start-line start-column end-line end-column)
      (setf (%buffer-narrow-start-offset buffer) start-offset
            (%buffer-narrow-end-offset buffer) end-offset)
      (%clamp-buffer-point-and-mark-to-visible-region
       buffer point-offset mark-offset)))
  buffer)

(defun buffer-widen (buffer)
  "Make all of BUFFER's full text visible and editable. Returns BUFFER."
  (setf (%buffer-narrow-start-offset buffer) 0
        (%buffer-narrow-end-offset buffer) (%buffer-full-length buffer))
  buffer)
