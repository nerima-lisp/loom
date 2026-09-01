(in-package #:loom)

;;; ---------------------------------------------------------------------
;;; Piece-table splice and extraction helpers
;;;
;;; Representation stays in domain-buffer-storage.lisp. Position and line
;;; mapping live in domain-buffer-piece-table-position.lisp. This file owns
;;; the low-level splice/extraction algorithms used by the higher-level edit
;;; and accessor APIs.
;;; ---------------------------------------------------------------------

(defun %coalesce-pieces (pieces)
  "Merge adjacent slices from the same source, keeping metadata compact."
  (let ((result nil))
    (dolist (piece pieces (nreverse result))
      (let ((previous (first result)))
        (if (and previous
                 (eq (%piece-source previous) (%piece-source piece))
                 (= (+ (%piece-start previous) (%piece-length previous))
                    (%piece-start piece)))
            (incf (%piece-length previous) (%piece-length piece))
            (push piece result))))))

(defun %append-add-text (buffer text)
  "Append TEXT once and return its start offset and length in the add source."
  (let ((start (length (%buffer-add-buffer buffer))))
    (loop for character across text
          do (vector-push-extend character (%buffer-add-buffer buffer)))
    (values start (length text))))

(defun %insert-piece-fragments (piece cursor offset new-piece)
  (let* ((piece-length (%piece-length piece))
         (left-length (- offset cursor))
         (right-length (- (+ cursor piece-length) offset)))
    (values
     (append
      (when (plusp left-length)
        (list (%make-piece :source (%piece-source piece)
                           :start (%piece-start piece)
                           :length left-length)))
      (list new-piece)
      (when (plusp right-length)
        (list (%make-piece :source (%piece-source piece)
                           :start (+ (%piece-start piece) left-length)
                           :length right-length))))
     t)))

(defun %append-piece-fragments (result fragments)
  (dolist (fragment fragments result)
    (push fragment result)))

(defun %splice-insert-piece-step (piece cursor offset new-piece result inserted)
  (if (or inserted
          (< offset cursor)
          (> offset (+ cursor (%piece-length piece))))
      (values (push piece result) inserted)
      (values (%append-piece-fragments
               result
               (%insert-piece-fragments piece cursor offset new-piece))
              t)))

(defun %splice-insert-piece (buffer offset new-piece)
  (let ((result nil) (cursor 0) (inserted nil))
    (dolist (piece (%buffer-pieces buffer))
      (multiple-value-setq (result inserted)
        (%splice-insert-piece-step piece cursor offset new-piece result inserted))
      (incf cursor (%piece-length piece)))
    (unless inserted
      (push new-piece result))
    (setf (%buffer-pieces buffer) (%coalesce-pieces (nreverse result)))))

(defun %piece-outside-delete-range-p (cursor next start end)
  (or (<= next start) (>= cursor end)))

(defun %delete-piece-fragments (piece cursor start end)
  (let* ((piece-length (%piece-length piece))
         (prefix-length (max 0 (- start cursor)))
         (suffix-offset (max 0 (- end cursor))))
    (append
     (when (plusp prefix-length)
       (list (%make-piece :source (%piece-source piece)
                          :start (%piece-start piece)
                          :length prefix-length)))
     (when (< suffix-offset piece-length)
       (list (%make-piece :source (%piece-source piece)
                          :start (+ (%piece-start piece) suffix-offset)
                          :length (- piece-length suffix-offset)))))))

(defun %splice-delete-range (buffer start end)
  (let ((result nil) (cursor 0))
    (dolist (piece (%buffer-pieces buffer))
      (let ((next (+ cursor (%piece-length piece))))
        (if (%piece-outside-delete-range-p cursor next start end)
            (push piece result)
            (dolist (fragment (%delete-piece-fragments piece cursor start end))
              (push fragment result)))
        (setf cursor next)))
    (setf (%buffer-pieces buffer) (%coalesce-pieces (nreverse result)))))

(defun %piece-range-overlap (cursor next start end)
  (when (and (< cursor end) (> next start))
    (values (max start cursor)
            (min end next))))

(defun %write-piece-range (stream buffer piece cursor start end)
  (multiple-value-bind (slice-start slice-end)
      (%piece-range-overlap cursor (+ cursor (%piece-length piece)) start end)
    (when slice-start
      (write-string
       (subseq (%piece-text buffer piece)
               (- slice-start cursor)
               (- slice-end cursor))
       stream))))

(defun %piece-table-range-text (buffer start end)
  (with-output-to-string (stream)
    (let ((cursor 0))
      (dolist (piece (%buffer-pieces buffer))
        (%write-piece-range stream buffer piece cursor start end)
        (incf cursor (%piece-length piece))))))

(defun %raw-insert-at (buffer line column text)
  "Splice TEXT into the piece table at (LINE, COLUMN), without undo bookkeeping."
  (multiple-value-bind (start length) (%append-add-text buffer text)
    (when (plusp length)
      (%splice-insert-piece buffer (%position-to-offset buffer line column)
                            (%make-piece :source :add :start start :length length))))
  (%advance-position line column text))

(defun %raw-delete-region (buffer start-line start-column end-line end-column)
  "Remove text between two positions from the piece table without undo bookkeeping."
  (let ((start (%position-to-offset buffer start-line start-column))
        (end (%position-to-offset buffer end-line end-column)))
    (when (< start end)
      (%splice-delete-range buffer start end))))
