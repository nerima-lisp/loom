
(in-package #:loom/core/buffer)

(defun buffer-modified-p (buffer)
  "Return true if BUFFER has unsaved changes since it was created, loaded,
or last saved."
  (%buffer-modified-p buffer))

(defun buffer-read-only-p (buffer)
  "Return true when BUFFER rejects text mutations."
  (%buffer-read-only-p buffer))

(defun buffer-set-read-only (buffer read-only-p)
  "Set whether BUFFER rejects text mutations and return BUFFER."
  (setf (%buffer-read-only-p buffer) (not (null read-only-p)))
  buffer)

(defun buffer-mark-saved (buffer)
  "Mark BUFFER as having no unsaved changes and return BUFFER."
  (setf (%buffer-modified-p buffer) nil)
  buffer)

(defun buffer-mark-modified (buffer)
  "Mark BUFFER as having unsaved changes and return BUFFER.

This is intentionally separate from BUFFER-INSERT-STRING and the other edit
operations: session restoration must be able to restore the saved/modified
invariant without manufacturing an undo entry or changing point."
  (setf (%buffer-modified-p buffer) t)
  buffer)

(defun buffer-undo (buffer)
  "Undo the most recent change group in BUFFER, Emacs ring-style.
Repeated calls keep walking through inverse history. The inverse group remains
available to BUFFER-REDO. Returns BUFFER."
  (%ensure-buffer-writable buffer)
  ;; Command dispatch can leave a transition boundary before the latest group.
  (when (eq (car (%buffer-undo-list buffer)) :boundary)
    (pop (%buffer-undo-list buffer)))
  (let ((group (loop for entry = (pop (%buffer-undo-list buffer))
                     until (or (null entry) (eq entry :boundary))
                     collect entry)))
    (when group
      (push :boundary (%buffer-redo-list buffer))
      (dolist (entry group)
        (push (%apply-undo-entry buffer entry
                                 (not (eq (first entry) :insert)))
              (%buffer-redo-list buffer)))
      ;; A same-position insert/delete pair is a replacement. Keep its saved point.
      (when (and (= (length group) 2)
                 (not (eq (first (first group))
                          (first (second group))))
                 (= (second (first group))
                    (second (second group)))
                 (= (third (first group))
                    (third (second group))))
        (buffer-set-point buffer
                          (fifth (second group))
                          (sixth (second group)))))
  buffer))

(defun buffer-redo (buffer)
  "Redo the most recently undone change group in BUFFER.

Redo is a no-op when no explicit redo history remains. A subsequent normal
edit clears the redo history. Returns BUFFER."
  (%ensure-buffer-writable buffer)
    (let ((group (loop for entry = (pop (%buffer-redo-list buffer))
                       until (or (null entry) (eq entry :boundary))
                       collect entry)))
      (dolist (entry group)
        (%apply-undo-entry buffer entry)))
  buffer)

(defun buffer-record-undo-boundary (buffer)
  "Record an undo boundary in BUFFER, so edits made before this call and
edits made after it belong to distinct undo groups that BUFFER-UNDO steps
between independently. Returns BUFFER."
  (unless (eq (car (%buffer-undo-list buffer)) :boundary)
    (push :boundary (%buffer-undo-list buffer)))
  buffer)
