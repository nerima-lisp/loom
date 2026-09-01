;;;; packages/core/editor/src/application-structural-editing-application.lisp
;;;;
;;;; Side-effecting application of the structural edit plan.
(in-package #:loom)

(defun %apply-structural-edits (buffer start edits)
  "Apply EDITS, whose offsets are relative to START, to BUFFER.

The edits run from the highest offset down, so each one is applied while the
offsets of the ones still to come are still describing the text they were
computed against. They are one undo group because nothing between them records
an undo boundary."
  (dolist (edit (sort (copy-list edits) #'> :key #'second))
    (ecase (first edit)
      (:insert
       (%move-point-to-offset buffer (+ start (second edit)))
       (buffer-insert-string buffer (third edit)))
      (:delete
       (let ((from (buffer-offset-position buffer (+ start (second edit))))
             (to (buffer-offset-position buffer
                                         (+ start (second edit) (third edit)))))
         (buffer-delete-region buffer
                               (buffer-position-line from)
                               (buffer-position-column from)
                               (buffer-position-line to)
                               (buffer-position-column to)))))))
