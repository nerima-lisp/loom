;;;; packages/core/editor/src/domain-buffer-narrowing.lisp
;;;;
;;;; Domain layer: visible-region queries and narrowing APIs layered on top of
;;;; the core buffer protocol in domain-buffer.lisp.
(in-package #:loom)

(defgeneric buffer-narrow-start-offset (buffer)
  (:documentation
   "Return the absolute, inclusive start offset of BUFFER's visible region.")
  (:method (buffer)
    (%buffer-narrow-start-offset buffer)))

(defgeneric buffer-narrow-end-offset (buffer)
  (:documentation
   "Return the absolute, exclusive end offset of BUFFER's visible region.")
  (:method (buffer)
    (%buffer-narrow-end-offset buffer)))

(defgeneric buffer-narrowed-p (buffer)
  (:documentation "Return true when BUFFER is displaying a narrowed region.")
  (:method (buffer)
    (%buffer-narrowed-p buffer)))

(defgeneric buffer-visible-text (buffer)
  (:documentation
   "Return the text in BUFFER's current visible region, excluding hidden text.")
  (:method (buffer)
    (subseq (buffer-text buffer)
            (%buffer-narrow-start-offset buffer)
            (%buffer-narrow-end-offset buffer))))

(defgeneric buffer-visible-line-count (buffer)
  (:documentation "Return the number of lines in BUFFER's visible region.")
  (:method (buffer)
    (length (%visible-lines buffer))))

(defgeneric buffer-visible-line (buffer line-number)
  (:documentation
   "Return the zero-based LINE-NUMBER text in BUFFER's visible region.")
  (:method (buffer line-number)
    (let ((lines (%visible-lines buffer)))
      (unless (and (>= line-number 0) (< line-number (length lines)))
        (error "buffer-visible-line: line-number ~D out of range [0,~D)"
               line-number (length lines)))
      (nth line-number lines))))

(defgeneric buffer-visible-point-line (buffer)
  (:documentation "Return point's zero-based line within BUFFER's visible region.")
  (:method (buffer)
    (multiple-value-bind (line column)
        (%text-offset-to-position-values
         (buffer-visible-text buffer)
         (- (buffer-point-offset buffer) (%buffer-narrow-start-offset buffer)))
      (declare (ignore column))
      line)))

(defgeneric buffer-visible-point-column (buffer)
  (:documentation "Return point's zero-based column within BUFFER's visible region.")
  (:method (buffer)
    (multiple-value-bind (line column)
        (%text-offset-to-position-values
         (buffer-visible-text buffer)
         (- (buffer-point-offset buffer) (%buffer-narrow-start-offset buffer)))
      (declare (ignore line))
      column)))

(defgeneric buffer-narrow-to-region
    (buffer start-line start-column end-line end-column)
  (:documentation
   "Limit BUFFER's visible and editable region to the half-open region
between the two zero-based positions. Point and mark are clamped into the
new region. Returns BUFFER.")
  (:method (buffer start-line start-column end-line end-column)
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
    buffer))

(defgeneric buffer-widen (buffer)
  (:documentation "Make all of BUFFER's full text visible and editable. Returns BUFFER.")
  (:method (buffer)
    (setf (%buffer-narrow-start-offset buffer) 0
          (%buffer-narrow-end-offset buffer) (%buffer-full-length buffer))
    buffer))
