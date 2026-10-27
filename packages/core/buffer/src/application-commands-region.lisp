(in-package #:loom)

(define-selected-buffer-command set-mark-command
  "Set mark to point's current position."
  %set-mark-at-point)

(define-selected-buffer-command exchange-point-and-mark
  "Exchange point and mark, or report that no mark is set (C-x C-x)."
  %exchange-point-and-mark-or-message)

(define-selected-buffer-command mark-whole-buffer
  "Set mark at the end and point at the start of the visible region (C-x h)."
  %mark-whole-buffer-region)

(define-selected-buffer-command narrow-to-region
  "Limit the selected buffer to the region between point and mark."
  %narrow-to-active-region-or-message)

(define-selected-buffer-command widen
  "Make the selected buffer's full text visible without changing read-only state."
  %widen-buffer-and-message)

(define-selected-buffer-command toggle-read-only
  "Toggle whether the selected buffer accepts text changes."
  %toggle-buffer-read-only)

(define-selected-buffer-command undo-command
  "Undo change groups, continuing through history on repeated calls."
  (lambda (buffer)
    (with-nonnegative-command-prefix (count)
      (loop repeat count
            for continue-p = (equal (loom/core/command:previous-command-id) "undo")
              then t
            do (buffer-undo buffer :continue-p continue-p)))))

(define-selected-buffer-command redo-command
  "Redo the most recently undone change groups in the selected buffer."
  (lambda (buffer)
    (let ((point-line (buffer-point-line buffer))
          (point-column (buffer-point-column buffer)))
      (with-nonnegative-command-prefix (count)
        (loop repeat count
              do (buffer-redo buffer))
        (when (> count 1) (buffer-set-point buffer point-line point-column))))))
