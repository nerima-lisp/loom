(in-package #:loom)

;;; ---------------------------------------------------------------------
;;; Piece-table splice algorithms
;;; ---------------------------------------------------------------------

(defun %insert-piece-fragment-list (piece cursor offset new-piece)
  (let* ((piece-length (%piece-length piece))
         (left-length (- offset cursor))
         (right-length (- (+ cursor piece-length) offset)))
    (append
     (when (plusp left-length)
       (list (%piece-left-fragment piece left-length)))
     (list new-piece)
     (when (plusp right-length)
       (list (%piece-right-fragment piece left-length right-length))))))

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
               (%insert-piece-fragment-list piece cursor offset new-piece))
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
       (list (%piece-left-fragment piece prefix-length)))
     (when (< suffix-offset piece-length)
       (list (%piece-right-fragment piece suffix-offset
                                    (- piece-length suffix-offset)))))))

(defun %splice-delete-piece-step (piece cursor start end result)
  (let ((next (+ cursor (%piece-length piece))))
    (if (%piece-outside-delete-range-p cursor next start end)
        (push piece result)
        (%append-piece-fragments
         result
         (%delete-piece-fragments piece cursor start end)))))

(defun %splice-delete-range (buffer start end)
  (let ((result nil) (cursor 0))
    (dolist (piece (%buffer-pieces buffer))
      (setf result (%splice-delete-piece-step piece cursor start end result))
      (incf cursor (%piece-length piece)))
    (setf (%buffer-pieces buffer) (%coalesce-pieces (nreverse result)))))
