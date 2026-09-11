(in-package #:loom)


(defun %adjacent-piece-p (previous piece)
  (and previous
       (eq (%piece-source previous) (%piece-source piece))
       (= (+ (%piece-start previous) (%piece-length previous))
          (%piece-start piece))))

(defun %merge-piece (previous piece)
  (incf (%piece-length previous) (%piece-length piece))
  previous)

(defun %coalesce-piece (piece result)
  (let ((previous (first result)))
    (if (%adjacent-piece-p previous piece)
        (progn
          (%merge-piece previous piece)
          result)
        (push piece result))))

(defun %coalesce-pieces (pieces)
  "Merge adjacent slices from the same source, keeping metadata compact."
  (nreverse
   (reduce (lambda (result piece)
             (%coalesce-piece piece result))
           pieces
           :initial-value nil)))
