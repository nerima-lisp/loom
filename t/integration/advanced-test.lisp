;;;; t/integration/advanced-test.lisp
;;;;
;;;; High-level cl-weave registrations over the real Loom buffer protocol.
(in-package #:loom/test)

(describe
  "cl-weave advanced registrations"
  (cl-weave:it-each
      ((0 "x" "xabc")
       (1 "x" "axbc")
       (3 "x" "abcx"))
      "inserts ~A at zero-based column ~D"
      (column inserted expected)
    (let ((buffer (make-buffer :initial-content "abc")))
      (buffer-set-point buffer 0 column)
      (buffer-insert-string buffer inserted)
      (expect (buffer-text buffer) :to-equal expected)
      (expect (buffer-point-column buffer)
              :to-equal (+ column (length inserted)))))

  (cl-weave:it-property
      "keeps generated insertion points and text consistent"
      ((column (cl-weave:gen-integer :min 0 :max 6))
       (character (cl-weave:gen-character :alphabet "abc")))
    (let* ((buffer (make-buffer :initial-content "abcdef"))
           (inserted (string character)))
      (buffer-set-point buffer 0 column)
      (buffer-insert-string buffer inserted)
      (expect (buffer-point-column buffer)
              :to-equal (1+ column))
      (expect (buffer-text buffer)
              :to-equal
              (concatenate 'string
                           (subseq "abcdef" 0 column)
                           inserted
                           (subseq "abcdef" column)))))

  (cl-weave:it-fuzz
      "accepts generated insertion positions"
      ((column (cl-weave:gen-integer :min 0 :max 6)))
      (:trials 16 :timeout-per-trial 1)
    (let ((buffer (make-buffer :initial-content "abcdef")))
      (buffer-set-point buffer 0 column)
      (buffer-insert-string buffer "!")
      (expect (buffer-point-column buffer) :to-equal (1+ column))
      (expect (length (buffer-text buffer)) :to-equal 7))))

  (it
    "keeps mixed piece-table edits equal to a reference model"
    (let ((buffer (make-buffer :initial-content ""))
          (reference "")
          (seed 17)
          (insertions (list ""
                            "a"
                            "bc"
                            (string #\Newline)
                            (format nil "x~%y")
                            (format nil "p~%q"))))
      (labels ((next-random ()
                 (setf seed (mod (+ (* seed 1103515245) 12345)
                                 2147483648)))
               (position-at (text offset)
                 (let ((line 0)
                       (column 0))
                   (loop for index below offset
                         do (if (char= (char text index) #\Newline)
                                (progn
                                  (incf line)
                                  (setf column 0))
                                (incf column)))
                   (values line column))))
        (dotimes (_step 256)
          (declare (ignore _step))
          (let ((kind (mod (next-random) 3))
                (size (length reference)))
            (if (or (zerop size) (zerop kind))
                (let* ((offset (mod (next-random) (1+ size)))
                       (inserted (nth (mod (next-random) (length insertions))
                                      insertions)))
                  (multiple-value-bind (line column)
                      (position-at reference offset)
                    (buffer-set-point buffer line column))
                  (buffer-insert-string buffer inserted)
                  (setf reference
                        (concatenate 'string
                                     (subseq reference 0 offset)
                                     inserted
                                     (subseq reference offset))))
                (let* ((start (mod (next-random) size))
                       (end (+ start (mod (next-random)
                                          (1+ (- size start))))))
                  (multiple-value-bind (start-line start-column)
                      (position-at reference start)
                    (multiple-value-bind (end-line end-column)
                        (position-at reference end)
                      (buffer-delete-region buffer
                                            start-line start-column
                                            end-line end-column)))
                  (setf reference
                        (concatenate 'string
                                     (subseq reference 0 start)
                                     (subseq reference end)))))
            (expect (buffer-text buffer) :to-equal reference)
            (expect (buffer-line-count buffer)
                    :to-equal (1+ (count #\Newline reference))))))))

(describe
  "continuation observations"
  (cl-weave:it
    "captures multiple buffer observations through a continuation"
    (let ((buffer (make-buffer :initial-content "alpha")))
      (cl-weave:with-continuation-values (observations next calledp)
          (funcall (lambda (continuation)
                     (funcall continuation
                              (buffer-text buffer)
                              (buffer-line-count buffer)))
                   #'next)
        (expect calledp :to-be-truthy)
        (expect observations :to-equal (list "alpha" 1))))))
