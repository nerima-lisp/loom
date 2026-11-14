
(in-package #:loom/core/buffer)

(defun %undo-group-and-tail (entries)
  (let ((group nil))
    (loop while (and entries (not (eq (first entries) :boundary)))
          do (push (pop entries) group))
    (values (nreverse group) (if entries (rest entries) nil))))

(defun %undo-generated-prefix (entries original)
  (loop for tail on entries until (eq tail original) collect (first tail)))


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

(defun buffer-undo (buffer &key continue-p)
  "Undo the latest change group in BUFFER. CONTINUE-P skips the inverse group recorded by the prior undo."
  (%ensure-buffer-writable buffer)
  (sb-sys:without-interrupts
    (let* ((original (%buffer-undo-list buffer))
           (entries (if (and continue-p
                             (plusp (%buffer-undo-continuation-count buffer)))
                        (nthcdr (1+ (%buffer-undo-continuation-count buffer)) original)
                        original)))
      (when (eq (first entries) :boundary)
        (setf entries (rest entries)))
      (multiple-value-bind (group tail) (%undo-group-and-tail entries)
        (if group
            (progn
              (push :boundary (%buffer-redo-list buffer))
              (dolist (entry group)
                (push (%apply-undo-entry buffer entry
                                         (not (eq (first entry) :insert)))
                      (%buffer-redo-list buffer)))
              ;; Replay records inverses before the still-intact source history.
              (setf (%buffer-undo-list buffer)
                    (nconc (%undo-generated-prefix (%buffer-undo-list buffer) original)
                           (cons :boundary tail))
                    (%buffer-undo-continuation-count buffer) (length group)))
            (setf (%buffer-undo-list buffer) tail
                  (%buffer-undo-continuation-count buffer) 0)))))
  buffer)

(defun buffer-redo (buffer)
  "Redo the most recently undone change group in BUFFER."
  (%ensure-buffer-writable buffer)
  (sb-sys:without-interrupts
    (multiple-value-bind (group tail)
        (%undo-group-and-tail (%buffer-redo-list buffer))
      (setf (%buffer-undo-continuation-count buffer) 0)
      (when group
        (push :boundary (%buffer-undo-list buffer))
        (dolist (entry group)
          (%apply-undo-entry buffer entry)))
      (setf (%buffer-redo-list buffer) tail)))
  buffer)

(defun buffer-record-undo-boundary (buffer)
  "Record an undo boundary in BUFFER, so edits made before this call and
edits made after it belong to distinct undo groups that BUFFER-UNDO steps
between independently. Returns BUFFER."
  (unless (eq (car (%buffer-undo-list buffer)) :boundary)
    (push :boundary (%buffer-undo-list buffer)))
  buffer)
