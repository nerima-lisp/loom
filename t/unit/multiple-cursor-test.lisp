;;;; t/unit/multiple-cursor-test.lisp
;;;;
;;;; The multiple-cursor feature keeps transient cursor positions as buffer
;;;; offsets.  These tests pin down the offset model and the editing contract
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

(describe
  "multiple-cursor deletion"
  (it
    "deletes one character at every cursor"
    (let ((*editor-state* (%fresh-editor-state (format nil "abc~%def"))))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 1)
        (multiple-cursors-add-next-line)
        (loom::delete-char)
        (expect (buffer-text buffer)
                :to-equal (format nil "ac~%df"))
        (expect (multiple-cursor-set-offsets
                 (editor-state-multiple-cursors *editor-state*))
                :to-equal '(1 4))
        (expect buffer :to-have-point (cons 0 1)))))

  (it
    "deletes backward at every cursor"
    (let ((*editor-state* (%fresh-editor-state (format nil "abc~%def"))))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 2)
        (multiple-cursors-add-next-line)
        (loom::delete-backward-char)
        (expect (buffer-text buffer)
                :to-equal (format nil "ac~%df"))
        (expect (multiple-cursor-set-offsets
                 (editor-state-multiple-cursors *editor-state*))
                :to-equal '(1 4))
        (expect buffer :to-have-point (cons 0 1))))))

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
