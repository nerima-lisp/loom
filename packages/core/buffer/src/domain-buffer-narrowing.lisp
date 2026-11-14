(in-package #:loom/core/buffer)

(defun buffer-narrow-start-offset (buffer)
  "Return the absolute, inclusive start offset of BUFFER's visible region."
  (%buffer-narrow-start-offset buffer))

(defun buffer-narrow-start-line (buffer)
  "Return the absolute line containing BUFFER's visible-region start."
  (%buffer-narrow-start-line buffer))

(defun buffer-narrow-end-offset (buffer)
  "Return the absolute, exclusive end offset of BUFFER's visible region."
  (%buffer-narrow-end-offset buffer))

(defun buffer-narrowed-p (buffer)
  "Return true when BUFFER is displaying a narrowed region."
  (%buffer-narrowed-p buffer))

(defun buffer-visible-text (buffer)
  "Return the text in BUFFER's current visible region, excluding hidden text."
  (%piece-table-range-text buffer
                          (%buffer-narrow-start-offset buffer)
                          (%buffer-narrow-end-offset buffer)))

(defun buffer-visible-line-count (buffer)
  "Return the visible line count for BUFFER."
  (%buffer-visible-view-line-count (%current-buffer-visible-view buffer)))

(defun buffer-visible-line (buffer line-number)
  "Return zero-based LINE-NUMBER from the visible region of BUFFER."
  (let* ((view (%current-buffer-visible-view buffer))
         (count (%buffer-visible-view-line-count view)))
    (unless (<= 0 line-number (1- count))
      (error "buffer-visible-line: line-number ~D out of range [0,~D)"
             line-number count))
    (%buffer-visible-view-line buffer view line-number)))

(defun buffer-visible-point-line (buffer)
  "Return point's zero-based line within BUFFER's visible region."
  (- (%buffer-point-line buffer) (%buffer-narrow-start-line buffer)))

(defun buffer-visible-point-column (buffer)
  "Return point's zero-based column within BUFFER's visible region."
  (let ((first-line (%buffer-narrow-start-line buffer)))
    (if (= (%buffer-point-line buffer) first-line)
        (- (%buffer-point-column buffer)
           (- (%buffer-narrow-start-offset buffer)
              (%line-index-offset buffer first-line)))
        (%buffer-point-column buffer))))

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
  (check-type start-line (integer 0 *))
  (check-type line-limit (integer 0 *))
  (let* ((view (%current-buffer-visible-view buffer))
         (count (%buffer-visible-view-line-count view)))
    (values (loop for line from start-line below (min count (+ start-line line-limit))
                  collect (%buffer-visible-view-line buffer view line))
            count)))
