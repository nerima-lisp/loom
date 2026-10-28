(in-package #:loom/core/buffer)

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
  "Return the visible line count for BUFFER."
  (let ((index (%buffer-visible-line-index buffer)))
    (if index
        (length (%visible-line-index-line-starts index))
        (nth-value 1 (%visible-line-scan buffer)))))

(defun buffer-visible-line (buffer line-number)
  "Return zero-based LINE-NUMBER from the visible region of BUFFER."
  (let ((index (%buffer-visible-line-index buffer)))
    (if index
        (multiple-value-bind (line found-p)
            (%visible-line-index-line index line-number)
          (unless found-p
            (error "buffer-visible-line: line-number ~D out of range [0,~D)"
                   line-number (length (%visible-line-index-line-starts index))))
          line)
        (multiple-value-bind (line line-count found-p)
            (%visible-line-scan buffer line-number)
          (unless found-p
            (error "buffer-visible-line: line-number ~D out of range [0,~D)"
                   line-number line-count))
          line))))

(defun buffer-visible-point-line (buffer)
  "Return point's zero-based line within BUFFER's visible region."
  (if (buffer-narrowed-p buffer)
      (multiple-value-bind (line column)
          (%text-offset-to-position-values
           (buffer-visible-text buffer)
           (- (buffer-point-offset buffer)
              (%buffer-narrow-start-offset buffer)))
        (declare (ignore column))
        line)
      (%buffer-point-line buffer)))

(defun buffer-visible-point-column (buffer)
  "Return point's zero-based column within BUFFER's visible region."
  (if (buffer-narrowed-p buffer)
      (multiple-value-bind (line column)
          (%text-offset-to-position-values
           (buffer-visible-text buffer)
           (- (buffer-point-offset buffer)
              (%buffer-narrow-start-offset buffer)))
        (declare (ignore line))
        column)
      (%buffer-point-column buffer)))

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
  "Remove narrowing so all of BUFFER's text is visible.
Leave BUFFER's read-only state unchanged. Returns BUFFER."
  (setf (%buffer-narrow-start-offset buffer) 0
        (%buffer-narrow-end-offset buffer) (%buffer-full-length buffer))
  buffer)
(defun buffer-visible-lines (buffer start-line line-limit)
  "Return up to LINE-LIMIT visible lines beginning at START-LINE, plus total line count."
  (let ((index (%buffer-visible-line-index buffer)))
    (if index
        (%visible-line-index-lines index start-line line-limit)
        (%visible-lines-scan buffer start-line line-limit))))
