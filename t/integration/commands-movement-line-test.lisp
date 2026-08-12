(in-package #:loom/test)

(describe
  "movement commands line motion"
  (it
    "next-line moves point down one line, clamping column to its length"
    (let ((*editor-state* (%fresh-editor-state (format nil "hello~%hi"))))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 4)
        (loom::next-line)
        (expect buffer :to-have-point (cons 1 2)))))

  (it
    "previous-line moves point up one line, clamping column to its length"
    (let ((*editor-state* (%fresh-editor-state (format nil "hi~%hello"))))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 1 4)
        (loom::previous-line)
        (expect buffer :to-have-point (cons 0 2)))))

  (it
    "move-end-of-line then move-beginning-of-line round-trips point"
    (let ((*editor-state* (%fresh-editor-state "hello")))
      (let ((buffer (%selected-test-buffer)))
        (loom::move-end-of-line)
        (expect (buffer-point-column buffer) :to-equal 5)
        (loom::move-beginning-of-line)
        (expect (buffer-point-column buffer) :to-equal 0)))))
