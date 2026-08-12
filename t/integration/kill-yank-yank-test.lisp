;;;; t/integration/kill-yank-yank-test.lisp

(in-package #:loom/test)

(describe
  "kill and yank commands"
  (it
    "rotates yank-pop by replacing the previous yank"
    (let ((*editor-state* (%fresh-editor-state "")))
      (let ((buffer (%selected-test-buffer)))
        (setf (editor-state-kill-ring *editor-state*) '("one" "two" "three"))
        (loom::yank)
        (expect (buffer-text buffer) :to-equal "one")
        (loom::yank-pop)
        (expect (buffer-text buffer) :to-equal "two")
        (loom::yank-pop)
        (expect (buffer-text buffer) :to-equal "three")
        (loom::yank-pop)
        (expect (buffer-text buffer) :to-equal "one"))))

  (it
    "kills from point to end of line and yanks it back at a new position"
    (let ((*editor-state* (%fresh-editor-state "hello world")))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 5)
        (loom::kill-line)
        (expect (buffer-line buffer 0) :to-equal "hello")
        (expect (first (editor-state-kill-ring *editor-state*)) :to-equal " world")
        (buffer-set-point buffer 0 0)
        (loom::yank)
        (expect (buffer-line buffer 0) :to-equal " worldhello"))))

  (it
    "trims the kill ring to +kill-ring-max+ entries, dropping the oldest"
    (let ((*editor-state* (%fresh-editor-state "")))
      (dotimes (i (+ loom::+kill-ring-max+ 10))
        (loom::%kill-ring-push (format nil "entry-~D" i)))
      (expect (length (editor-state-kill-ring *editor-state*))
              :to-equal loom::+kill-ring-max+)
      (expect (first (editor-state-kill-ring *editor-state*))
              :to-equal (format nil "entry-~D"
                                (1- (+ loom::+kill-ring-max+ 10)))))))

  (it
    "coalesces adjacent kill-word commands"
    (let ((*editor-state* (%fresh-editor-state "alpha beta gamma")))
      (loom::kill-word)
      (loom::kill-word)
      (expect (buffer-text (%selected-test-buffer)) :to-equal " gamma")
      (expect (editor-state-kill-ring *editor-state*) :to-equal '("alpha beta"))))

  (it
    "coalesces adjacent backward-kill-word commands"
    (let ((*editor-state* (%fresh-editor-state "alpha beta gamma")))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 16)
        (loom::backward-kill-word)
        (loom::backward-kill-word)
        (expect (buffer-text buffer) :to-equal "alpha ")
        (expect (editor-state-kill-ring *editor-state*)
                :to-equal '("beta gamma")))))
