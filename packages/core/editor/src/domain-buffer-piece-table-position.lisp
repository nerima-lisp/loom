(in-package #:loom)

;;; ---------------------------------------------------------------------
;;; Piece-table position and line mapping helpers
;;;
;;; Representation stays in domain-buffer-storage.lisp. These helpers map
;;; between piece-table offsets, line/column positions, and line-oriented
;;; views of the current buffer text.
;;; ---------------------------------------------------------------------

(defun %position-to-offset (buffer line column)
  (let ((current-line 0) (current-column 0) (offset 0))
    (dolist (piece (%buffer-pieces buffer))
      (loop for character across (%piece-text buffer piece)
            do (when (and (= current-line line) (= current-column column))
                 (return-from %position-to-offset offset))
               (incf offset)
               (if (char= character #\Newline)
                   (progn
                     (incf current-line)
                     (setf current-column 0))
                   (incf current-column))))
    (if (and (= current-line line) (= current-column column))
        offset
        (error "buffer position (~D, ~D) out of range" line column))))

(defun %line-count (buffer)
  (let ((count 1))
    (dolist (piece (%buffer-pieces buffer) count)
      (loop for character across (%piece-text buffer piece)
            when (char= character #\Newline)
              do (incf count)))))

(defun %line-at (buffer line-number)
  "Return the text of LINE-NUMBER, not including its trailing newline.
Trusts its callers -- %CLAMP-POSITION, BUFFER-LINE (which validates
LINE-NUMBER itself before calling this), and BUFFER-DELETE-CHAR's
backward/forward helpers (which derive it from BUFFER's own point) -- to
never pass an out-of-range LINE-NUMBER; this is an internal helper, not a
system boundary. The scan ends either at the newline closing LINE-NUMBER or,
for BUFFER's last line, at the end of the pieces, since that line has no
closing newline; both leave TEXT holding the answer."
  (let ((current-line 0)
        (text (make-string-output-stream)))
    (block scan
      (dolist (piece (%buffer-pieces buffer))
        (loop for character across (%piece-text buffer piece)
              for newline-p = (char= character #\Newline)
              for on-target-line-p = (= current-line line-number)
              when (and newline-p on-target-line-p) do (return-from scan)
              when newline-p do (incf current-line)
              when on-target-line-p do (write-char character text))))
    (get-output-stream-string text)))

(defun %clamp-position (buffer line column)
  "Clamp (LINE, COLUMN) into BUFFER valid bounds."
  (let* ((line-count (%line-count buffer))
         (clamped-line (max 0 (min line (1- line-count))))
         (line-len (length (%line-at buffer clamped-line)))
         (clamped-column (max 0 (min column line-len))))
    (values clamped-line clamped-column)))

(defun %offset-to-position-values (buffer offset)
  "Return (VALUES LINE COLUMN) for OFFSET in BUFFER's full text."
  (let ((remaining offset))
    (loop for line below (%line-count buffer)
          for line-length = (length (%line-at buffer line))
          if (<= remaining line-length)
            do (return (values line remaining))
          do (decf remaining (1+ line-length))
          finally (let ((last-line (1- (%line-count buffer))))
                    (return
                      (values last-line
                              (length (%line-at buffer last-line))))))))
