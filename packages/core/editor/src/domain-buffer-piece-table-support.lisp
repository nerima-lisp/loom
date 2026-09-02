(in-package #:loom)

;;; ---------------------------------------------------------------------
;;; Piece-table splice and extraction helpers
;;;
;;; Representation stays in domain-buffer-storage.lisp. Position and line
;;; mapping live in domain-buffer-piece-table-position.lisp. This file owns
;;; the low-level splice/extraction algorithms used by the higher-level edit
;;; and accessor APIs.
;;; ---------------------------------------------------------------------

(defun %append-add-text (buffer text)
  "Append TEXT once and return its start offset and length in the add source."
  (let ((start (length (%buffer-add-buffer buffer))))
    (loop for character across text
          do (vector-push-extend character (%buffer-add-buffer buffer)))
    (values start (length text))))

(defun %piece-left-fragment (piece length)
  (when (plusp length)
    (%make-piece :source (%piece-source piece)
                 :start (%piece-start piece)
                 :length length)))

(defun %piece-right-fragment (piece offset length)
  (when (plusp length)
    (%make-piece :source (%piece-source piece)
                 :start (+ (%piece-start piece) offset)
                 :length length)))

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
