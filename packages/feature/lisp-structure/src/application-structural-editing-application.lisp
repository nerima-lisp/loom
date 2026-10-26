(in-package #:loom)

(defun %apply-structural-insertion (buffer start edit)
  (%move-point-to-offset buffer (+ start (second edit)))
  (buffer-insert-string buffer (third edit)))

(defun %structural-edit-position (buffer start offset)
  (buffer-offset-position buffer (+ start offset)))

(defun %apply-structural-deletion (buffer start edit)
  (let* ((offset (second edit))
         (from (%structural-edit-position buffer start offset))
         (to (%structural-edit-position buffer start (+ offset (third edit)))))
    (buffer-delete-region buffer
                          (buffer-position-line from)
                          (buffer-position-column from)
                          (buffer-position-line to)
                          (buffer-position-column to))))

(defun %apply-structural-edit (buffer start edit)
  (ecase (first edit)
    (:insert (%apply-structural-insertion buffer start edit))
    (:delete (%apply-structural-deletion buffer start edit))))

(defun %apply-structural-edits (buffer start edits &optional order)
  "Apply EDITS relative to START. :AS-LISTED uses adjusted offsets in order;
otherwise edits run highest to lowest offset. Both forms are one undo group."
  (dolist (edit (if (eq order :as-listed)
                    edits
                    (sort (copy-list edits) (function >) :key (function second))))
    (%apply-structural-edit buffer start edit)))
