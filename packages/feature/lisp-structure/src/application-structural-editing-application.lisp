(in-package #:loom)

(defun %apply-structural-insertion (buffer start edit)
  (%move-point-to-offset buffer (+ start (second edit)))
  (buffer-insert-string buffer (third edit)))

(defun %structural-edit-position (buffer start offset)
  (buffer-offset-position buffer (+ start offset)))

(defun %apply-structural-deletion (buffer start edit &optional preserve-point-p)
  (let* ((offset (second edit))
         (from (%structural-edit-position buffer start offset))
         (to (%structural-edit-position buffer start (+ offset (third edit)))))
    ;; Group-leading deletion must retain the invocation point for undo.
    (unless preserve-point-p
      (loom/core/buffer:buffer-set-point buffer
                                         (buffer-position-line to)
                                         (buffer-position-column to)))
    (buffer-delete-region buffer
                          (buffer-position-line from)
                          (buffer-position-column from)
                          (buffer-position-line to)
                          (buffer-position-column to))))

(defun %apply-structural-edit (buffer start edit &optional preserve-point-p)
  (ecase (first edit)
    (:insert (%apply-structural-insertion buffer start edit))
    (:delete
     (%apply-structural-deletion buffer start edit preserve-point-p))))

(defun %apply-structural-edits (buffer start edits &optional order)
  "Apply EDITS relative to START. :AS-LISTED uses adjusted offsets in order;
otherwise edits run highest to lowest offset. Both forms are one undo group."
  (loop for edit in (if (eq order :as-listed)
                        edits
                        (sort (copy-list edits) (function >) :key (function second)))
        for preserve-point-p = t then nil
        do (%apply-structural-edit buffer start edit preserve-point-p)))
