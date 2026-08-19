;;;; t/unit/multiple-cursor-yank-test.lisp
;;;;
;;;; Multiple-cursor yank operations should reuse one kill-ring entry
;;;; consistently across all active cursors.
(in-package #:loom/test)

(describe
  "multiple-cursor yank"
  (it
    "yanks and rotates the same kill-ring entry at every cursor"
    (let ((*editor-state* (%fresh-editor-state (format nil "aa~%bb"))))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 1)
        (multiple-cursors-add-next-line)
        (setf (editor-state-kill-ring *editor-state*) '("old" "N"))
        (loom::yank)
        (expect (buffer-text buffer)
                :to-equal (format nil "aolda~%boldb"))
        (expect (editor-state-last-yank-ranges *editor-state*)
                :to-equal '((1 . 4) (7 . 10)))
        (expect (multiple-cursor-set-offsets
                 (editor-state-multiple-cursors *editor-state*))
                :to-equal '(4 10))
        (expect buffer :to-have-point (cons 0 4))
        (loom::yank-pop)
        (expect (buffer-text buffer)
                :to-equal (format nil "aNa~%bNb"))
        (expect (editor-state-last-yank-ranges *editor-state*)
                :to-equal '((1 . 2) (5 . 6)))
        (expect (multiple-cursor-set-offsets
                 (editor-state-multiple-cursors *editor-state*))
                :to-equal '(2 6))
        (expect buffer :to-have-point (cons 0 2))))))
