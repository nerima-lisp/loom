;;;; packages/core/editor/src/domain-buffer-positions.lisp
;;;;
;;;; Domain layer: buffer offset and position value types plus conversions
;;;; layered on top of the core buffer protocol in domain-buffer.lisp.
(in-package #:loom)

(deftype buffer-offset ()
  "A non-negative character offset in BUFFER-TEXT."
  '(integer 0 *))

(defstruct (buffer-position
            (:constructor %make-buffer-position (line column)))
  "A zero-based line and column position in a buffer."
  (line 0 :type buffer-offset)
  (column 0 :type buffer-offset))

(defstruct (buffer-span
            (:constructor make-buffer-span (start end)))
  "A half-open character-offset span in a buffer."
  (start 0 :type buffer-offset)
  (end 0 :type buffer-offset))

(defun buffer-visible-offset-position (buffer offset)
  "Return the visible-region BUFFER-POSITION for absolute OFFSET, or NIL
when OFFSET is outside BUFFER's current visible region. The region end is
accepted as the position just after its last visible character."
  (when (and (<= (%buffer-narrow-start-offset buffer) offset)
             (<= offset (%buffer-narrow-end-offset buffer)))
    (multiple-value-bind (line column)
        (%text-offset-to-position-values
         (buffer-visible-text buffer)
         (- offset (%buffer-narrow-start-offset buffer)))
      (%make-buffer-position line column))))

(defun buffer-point-offset (buffer)
  "Return BUFFER's point as an offset in BUFFER-TEXT."
  (let ((offset (buffer-point-column buffer)))
    (loop for line below (buffer-point-line buffer)
          do (incf offset (1+ (length (buffer-line buffer line)))))
    offset))

(defun buffer-offset-position (buffer offset)
  "Return the BUFFER-POSITION corresponding to OFFSET in BUFFER-TEXT."
  (declare (type buffer-offset offset))
  (multiple-value-bind (line column)
      (%offset-to-position-values buffer offset)
    (%make-buffer-position line column)))
