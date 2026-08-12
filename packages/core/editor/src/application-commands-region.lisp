;;;; packages/core/editor/src/application-commands-region.lisp
;;;;
;;;; Application layer: mark/region, buffer narrowing, and undo/redo commands.
(in-package #:loom)

(define-selected-buffer-command set-mark-command
  "Set mark to point's current position."
  %set-mark-at-point)

(define-selected-buffer-command exchange-point-and-mark
  "Exchange point and mark, or report that no mark is set (C-x C-x)."
  %exchange-point-and-mark-or-message)

(define-selected-buffer-command mark-whole-buffer
  "Set the mark at the end and point at the beginning of the buffer (C-x h)."
  %mark-whole-buffer-region)

(define-selected-buffer-command narrow-to-region
  "Limit the selected buffer to the region between point and mark."
  %narrow-to-active-region-or-message)

(define-selected-buffer-command widen
  "Make the selected buffer's complete text visible and editable."
  %widen-buffer-and-message)

(define-selected-buffer-command toggle-read-only
  "Toggle whether the selected buffer accepts text changes."
  %toggle-buffer-read-only)

(define-selected-buffer-command undo-command
  "Undo the most recent change group in the selected buffer."
  buffer-undo)

(define-selected-buffer-command redo-command
  "Redo the most recently undone change group in the selected buffer."
  buffer-redo)
