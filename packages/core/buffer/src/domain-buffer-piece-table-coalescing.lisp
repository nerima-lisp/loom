(in-package #:loom/core/buffer)


(defun %adjacent-piece-p (previous piece)
  (and previous
       (eq (%piece-source previous) (%piece-source piece))
       (= (+ (%piece-start previous) (%piece-length previous))
          (%piece-start piece))))

(defun %merge-piece (previous piece)
  (%make-piece :source (%piece-source previous)
               :start (%piece-start previous)
               :length (+ (%piece-length previous) (%piece-length piece))))

(defun %coalesce-piece (piece result)
  (let ((previous (first result)))
    (if (%adjacent-piece-p previous piece)
        (cons (%merge-piece previous piece) (rest result))
        (cons piece result))))

(defun %coalesce-pieces (pieces)
  "Merge adjacent slices from the same source, keeping metadata compact."
  (nreverse
   (reduce (lambda (result piece)
             (%coalesce-piece piece result))
           pieces
           :initial-value nil)))
