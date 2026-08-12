;;;; packages/core/editor/src/domain-buffer-storage-support.lisp
;;;;
;;;; Internal piece-table storage helpers shared by buffer operations.
(in-package #:loom)

(defun %piece-source-text (buffer piece)
  (ecase (%piece-source piece)
    (:original (%buffer-original buffer))
    (:add (%buffer-add-buffer buffer))))

(defun %piece-text (buffer piece)
  (let ((source (%piece-source-text buffer piece)))
    (subseq source
            (%piece-start piece)
            (+ (%piece-start piece) (%piece-length piece)))))

(defun %pieces-text (buffer)
  (with-output-to-string (stream)
    (dolist (piece (%buffer-pieces buffer))
      (write-string (%piece-text buffer piece) stream))))
