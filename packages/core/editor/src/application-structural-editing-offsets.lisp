;;;; packages/core/editor/src/application-structural-editing-offsets.lisp
;;;;
;;;; Application layer: point offsets after a planned structural edit.
(in-package #:loom)

(defun %structural-offset-after-insert (offset edit)
  (let ((position (second edit)))
    (if (<= position offset)
        (+ offset (length (third edit)))
        offset)))

(defun %structural-offset-after-delete (offset edit)
  (let* ((position (second edit))
         (length (third edit))
         (end (+ position length)))
    (cond ((<= end offset) (- offset length))
          ((< position offset) position)
          (t offset))))

(defun %structural-adjusted-offset-after-edit (offset edit)
  (ecase (first edit)
    (:insert (%structural-offset-after-insert offset edit))
    (:delete (%structural-offset-after-delete offset edit))))

(defun %structural-adjusted-offset (edits offset)
  "Return where OFFSET ends up once EDITS have been applied."
  (reduce #'%structural-adjusted-offset-after-edit edits :initial-value offset))
