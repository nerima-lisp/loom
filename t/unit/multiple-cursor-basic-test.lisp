;;;; t/unit/multiple-cursor-basic-test.lisp
;;;;
;;;; The multiple-cursor feature keeps transient cursor positions as buffer
;;;; offsets. These tests pin down offset normalization and activation rules
;;;; independently from terminal key dispatch and rendering.
(in-package #:loom/test)

(describe
  "multiple cursors"
  (it
    "normalizes offsets and retains an explicit primary cursor"
    (let* ((buffer (make-buffer :initial-content "abc"))
           (set (make-multiple-cursor-set buffer '(3 1 3)
                                          :primary-offset 1)))
      (expect (multiple-cursor-set-buffer set) :to-be buffer)
      (expect (multiple-cursor-set-offsets set) :to-equal '(1 3))
      (expect (multiple-cursor-set-primary-offset set) :to-equal 1)))

  (it
    "adds the next line and inserts at every cursor through self-insert"
    (let ((*editor-state* (%fresh-editor-state (format nil "one~%two~%three"))))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 1)
        (expect (multiple-cursors-add-next-line) :to-be t)
        (let ((set (editor-state-multiple-cursors *editor-state*)))
          (expect (multiple-cursor-set-offsets set) :to-equal '(1 5))
          (expect (multiple-cursor-set-primary-offset set) :to-equal 1))
        (loom:self-insert-command #\X)
        (expect (buffer-text buffer)
                :to-equal (format nil "oXne~%tXwo~%three"))
        (expect buffer :to-have-point (cons 0 2))
        (let ((set (editor-state-multiple-cursors *editor-state*)))
          (expect (multiple-cursor-set-offsets set) :to-equal '(2 7))
          (expect (multiple-cursor-set-primary-offset set) :to-equal 2)))))

  (it
    "creates a cursor on every line between point and mark"
    (let ((*editor-state* (%fresh-editor-state (format nil "aa~%bb~%cc"))))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 1)
        (buffer-set-mark buffer 2 0)
        (expect (multiple-cursors-edit-lines) :to-be t)
        (expect (multiple-cursor-set-offsets
                 (editor-state-multiple-cursors *editor-state*))
                :to-equal '(1 4 7)))))

  (it
    "clears transient state and identifies preserving commands"
    (let ((*editor-state* (%fresh-editor-state (format nil "one~%two"))))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 0)
        (multiple-cursors-add-next-line)
        (expect (multiple-cursors-active-p buffer) :to-be t)
        (expect (multiple-cursors-preserving-command-p
                 'multiple-cursors-add-next-line)
                :to-be t)
        (expect (multiple-cursors-preserving-command-p 'self-insert-command)
                :to-be nil)
        (multiple-cursors-reset)
        (expect (multiple-cursors-active-p buffer) :to-be nil)))))
