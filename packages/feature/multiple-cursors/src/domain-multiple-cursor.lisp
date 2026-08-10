;;;; packages/feature/multiple-cursors/src/domain-multiple-cursor.lisp
;;;;
;;;; The domain value keeps cursor positions as character offsets.  Offsets
;;;; are stable while the application applies edits from right to left, and
;;;; the value itself contains no editor-state or terminal concerns.
(in-package #:loom/feature/multiple-cursors)

(defstruct (multiple-cursor-set
            (:constructor %make-multiple-cursor-set
                (buffer offsets primary-offset)))
  buffer
  offsets
  primary-offset)

(defun make-multiple-cursor-set (buffer offsets &key primary-offset)
  "Create a normalized cursor set for BUFFER.

OFFSETS are sorted and deduplicated.  PRIMARY-OFFSET defaults to the first
offset and must be one of the resulting offsets when supplied."
  (let ((normalized
          (sort (remove-duplicates (copy-list offsets) :test #'=) #'<)))
    (when (null normalized)
      (error "A multiple-cursor set needs at least one offset"))
    (dolist (offset normalized)
      (check-type offset (integer 0 *)))
    (let ((primary (if (null primary-offset)
                       (first normalized)
                       primary-offset)))
      (check-type primary (integer 0 *))
      (unless (member primary normalized :test #'=)
        (error "Primary offset ~D is not in the cursor set" primary))
      (%make-multiple-cursor-set buffer normalized primary))))
