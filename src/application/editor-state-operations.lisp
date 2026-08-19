;;;; src/application/editor-state-operations.lisp
;;;;
;;;; Application-layer EDITOR-STATE helpers that do not justify their own
;;;; compilation unit yet.
(in-package #:loom)

(defun %clear-last-yank ()
  "Forget the range that YANK-POP may replace.

This lives beside EDITOR-STATE so both the input dispatcher and editing
commands can invalidate the transient yank state without duplicating the
slot-reset protocol."
  (setf (editor-state-last-yank-buffer *editor-state*) nil
        (editor-state-last-yank-start-offset *editor-state*) nil
        (editor-state-last-yank-end-offset *editor-state*) nil
        (editor-state-last-yank-ranges *editor-state*) nil
        (editor-state-last-yank-ring-index *editor-state*) nil
        (editor-state-last-yank-repeat-count *editor-state*) nil))
