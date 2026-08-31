;;;; packages/core/editor/src/domain-buffer-history.lisp
;;;;
;;;; Domain layer: buffer modification/read-only state and undo/redo history.
;;;; This file keeps the public history protocol separate from the core
;;;; buffer text/point/mark protocol in domain-buffer.lisp while sharing the
;;;; same piece-table primitives and undo replay helpers from
;;;; domain-buffer-storage.lisp and domain-buffer-piece-table-undo.lisp.

(in-package #:loom)

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
  "Undo the most recent change group in BUFFER, Emacs ring-style: repeated
calls to BUFFER-UNDO keep walking through the inverse history. The inverse
group is also made available to BUFFER-REDO. Once the history is exhausted,
further calls are a no-op (or signal, at the implementation's discretion).
Returns BUFFER."
  ;; BUFFER-UNDO keeps the existing ring behavior: its undo-list is a flat,
  ;; most-recent-first sequence of edit entries and :BOUNDARY markers. The
  ;; popped group's inverses are applied through the same mutation primitives
  ;; as ordinary edits, so the inverse-of-the-inverse remains on the undo ring
  ;; and the next BUFFER-UNDO call continues the ring-style walk. In parallel,
  ;; the returned inverse actions are copied to the explicit redo-list. Replay
  ;; passes CLEAR-REDO false, while ordinary edits clear redo history and start
  ;; a new branch.
  (%ensure-buffer-writable buffer)
    (let ((group (loop for entry = (pop (%buffer-undo-list buffer))
                       until (or (null entry) (eq entry :boundary))
                       collect entry)))
      (when group
        ;; Put the boundary below this group's entries. Since GROUP is
        ;; consumed newest-first, pushing each inverse reverses it back into
        ;; the original edit order for BUFFER-REDO.
        (push :boundary (%buffer-redo-list buffer))
        (dolist (entry group)
          (push (%apply-undo-entry buffer entry)
                (%buffer-redo-list buffer)))))
  buffer)

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
