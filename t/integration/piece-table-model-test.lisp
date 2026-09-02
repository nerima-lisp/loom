;;;; t/integration/piece-table-model-test.lisp
;;;;
;;;; A deterministic model check for mixed edits against the public buffer API.
(in-package #:loom/test)

(defun %model-position-at (text offset)
  (let ((line 0)
        (column 0))
    (loop for index below offset
          do (if (char= (char text index) #\Newline)
                 (progn
                   (incf line)
                   (setf column 0))
                 (incf column)))
    (values line column)))

(defun %model-next-random (state)
  (let ((next (mod (+ (* state 1103515245) 12345)
                   2147483648)))
    (values next next)))

(defun %model-random-index (state limit)
  (multiple-value-bind (random next-state)
      (%model-next-random state)
    (values (mod random limit) next-state)))

(defun %model-line-count (text)
  (1+ (count #\Newline text)))

(defun %model-apply-insertion (buffer reference state insertions)
  (let ((size (length reference)))
    (multiple-value-bind (offset state)
        (%model-random-index state (1+ size))
      (multiple-value-bind (insertion-index state)
          (%model-random-index state (length insertions))
        (let ((inserted (nth insertion-index insertions)))
    (multiple-value-bind (line column)
        (%model-position-at reference offset)
      (buffer-set-point buffer line column))
    (buffer-insert-string buffer inserted)
    (values (concatenate 'string
                         (subseq reference 0 offset)
                         inserted
                         (subseq reference offset))
            state))))))

(defun %model-apply-deletion (buffer reference state)
  (let ((size (length reference)))
    (multiple-value-bind (start state)
        (%model-random-index state size)
      (multiple-value-bind (length state)
          (%model-random-index state (1+ (- size start)))
        (let ((end (+ start length)))
    (multiple-value-bind (start-line start-column)
        (%model-position-at reference start)
      (multiple-value-bind (end-line end-column)
          (%model-position-at reference end)
        (buffer-delete-region buffer
                              start-line start-column
                              end-line end-column)))
    (values (concatenate 'string
                         (subseq reference 0 start)
                         (subseq reference end))
            state))))))

(describe
  "piece-table model behavior"
  (it
    "keeps mixed edits equal to a reference model"
    (let ((buffer (make-buffer :initial-content ""))
          (reference "")
          (state 17)
          (insertions (list ""
                            "a"
                            "bc"
                            (string #\Newline)
                            (format nil "x~%y")
                            (format nil "p~%q"))))
      (dotimes (_step 256)
        (multiple-value-bind (kind next-state)
            (%model-random-index state 3)
          (setf state next-state)
          (let ((size (length reference)))
          (if (or (zerop size) (zerop kind))
              (multiple-value-setq (reference state)
                (%model-apply-insertion buffer reference state insertions))
              (multiple-value-setq (reference state)
                (%model-apply-deletion buffer reference state)))))
        (expect (buffer-text buffer) :to-equal reference)
        (expect (buffer-line-count buffer)
                :to-equal (%model-line-count reference))))))
