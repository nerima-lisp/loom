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
    "does nothing when the kill ring is empty"
    (let ((*editor-state* (%fresh-editor-state "text")))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 2)
        (loom::yank)
        (expect (buffer-text buffer) :to-equal "text")
        (expect (loom::editor-state-last-command-kill-p *editor-state*) :to-be nil))))

  (it
    "does nothing for a zero yank prefix"
    (let ((*editor-state* (%fresh-editor-state "text"))
          (loom:*current-prefix-argument* 0))
      (let ((buffer (%selected-test-buffer)))
        (setf (editor-state-kill-ring *editor-state*) '("X"))
        (buffer-set-point buffer 0 2)
        (loom::yank)
        (expect (buffer-text buffer) :to-equal "text"))))

  (it
    "reports that yank-pop has no previous yank"
    (%with-minibuffer-state (minibuffer "")
      (loom::yank-pop)
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal "Previous command was not a yank")))

  (it
    "invalidates yank-pop after the point moves"
    (%with-minibuffer-state (minibuffer "one two")
      (let ((buffer (%selected-test-buffer)))
        (setf (editor-state-kill-ring *editor-state*) '("x" "y"))
        (loom::yank)
        (buffer-set-point buffer 0 0)
        (loom::yank-pop)
        (expect (buffer-text buffer) :to-equal "xone two")
        (expect (loom:minibuffer-message-string minibuffer)
                :to-equal "Previous command was not a yank"))))

  (it
    "rejects an incomplete previous yank context"
    (%with-minibuffer-state (minibuffer "one two")
      (let ((buffer (%selected-test-buffer)))
        (setf (editor-state-kill-ring *editor-state*) '("x" "y"))
        (loom::yank)
        (setf (editor-state-last-yank-ranges *editor-state*) nil)
        (loom::yank-pop)
        (expect (buffer-text buffer) :to-equal "xone two")
        (expect (loom:minibuffer-message-string minibuffer)
                :to-equal "Previous command was not a yank"))))

  (it
    "keeps yank-pop ranges ordered when an earlier range shifts later text"
    (let ((*editor-state* (%fresh-editor-state "aXXbYYc")))
      (let ((buffer (%selected-test-buffer)))
        (setf (editor-state-kill-ring *editor-state*) '("Z")
              (loom::editor-state-last-yank-buffer *editor-state*) buffer
              (loom::editor-state-last-yank-start-offset *editor-state*) 1
              (loom::editor-state-last-yank-end-offset *editor-state*) 6
              (editor-state-last-yank-ranges *editor-state*)
                '((1 . 3) (4 . 6))
              (loom::editor-state-last-yank-ring-index *editor-state*) 0
              (loom::editor-state-last-yank-repeat-count *editor-state*) 1)
        (buffer-set-point buffer 0 6)
        (loom::yank-pop)
        (expect (buffer-text buffer) :to-equal "aZbZc")
        (expect (buffer-point-offset buffer) :to-equal 2)
        (expect (editor-state-last-yank-ranges *editor-state*)
                :to-equal '((1 . 2) (3 . 4))))))

  (it
    "preserves the previous yank repeat count while rotating ranges"
    (let ((*editor-state* (%fresh-editor-state "aXXbYYc")))
      (let ((buffer (%selected-test-buffer)))
        (setf (editor-state-kill-ring *editor-state*) '("Z")
              (loom::editor-state-last-yank-buffer *editor-state*) buffer
              (loom::editor-state-last-yank-start-offset *editor-state*) 1
              (loom::editor-state-last-yank-end-offset *editor-state*) 6
              (editor-state-last-yank-ranges *editor-state*)
                '((1 . 3) (4 . 6))
              (loom::editor-state-last-yank-ring-index *editor-state*) 0
              (loom::editor-state-last-yank-repeat-count *editor-state*) 2)
        (buffer-set-point buffer 0 6)
        (loom::yank-pop)
        (expect (buffer-text buffer) :to-equal "aZZbZZc")
        (expect (loom::editor-state-last-yank-repeat-count *editor-state*)
                :to-equal 2))))

  (it
    "keeps point at the first replacement when the primary range is absent"
    (let ((*editor-state* (%fresh-editor-state "aXXbYYc")))
      (let ((buffer (%selected-test-buffer)))
        (setf (editor-state-kill-ring *editor-state*) '("Z")
              (loom::editor-state-last-yank-buffer *editor-state*) buffer
              (loom::editor-state-last-yank-start-offset *editor-state*) 0
              (loom::editor-state-last-yank-end-offset *editor-state*) 6
              (editor-state-last-yank-ranges *editor-state*)
                '((1 . 3) (4 . 6))
              (loom::editor-state-last-yank-ring-index *editor-state*) 0
              (loom::editor-state-last-yank-repeat-count *editor-state*) 1)
        (buffer-set-point buffer 0 6)
        (loom::yank-pop)
        (expect (buffer-text buffer) :to-equal "aZbZc")
        (expect (buffer-point-offset buffer) :to-equal 2))))

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
