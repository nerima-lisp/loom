(in-package #:loom/test)

(describe
  "kill and yank commands"
  (it
    "kill-word removes the next word and adds it to the kill ring"
    (%expect-word-kill (loom::kill-word "one two" " two" '("one"))))

  (it
    "backward-kill-word removes the previous word"
    (%expect-word-kill (loom::backward-kill-word "one two" "one " '("two")
                        :point (0 7))))

  (it
    "kill-word with a negative prefix removes the previous word"
    (%expect-word-kill (loom::kill-word "one two" "one " '("two")
                        :point (0 7)
                        :prefix -1)))

  (it
    "backward-kill-word with a negative prefix removes the next word"
    (%expect-word-kill (loom::backward-kill-word "one two" " two" '("one")
                        :point (0 0)
                        :prefix -1)))

  (it
    "kill-word is a no-op at the end of the buffer"
    (%expect-word-kill (loom::kill-word "one" "one" nil
                        :point (0 3))))

  (it
    "backward-kill-word is a no-op at the beginning of the buffer"
    (%expect-word-kill (loom::backward-kill-word "one" "one" nil
                        :point (0 0))))

  (it
    "kill-line at end of a non-last line kills through the newline"
    (let ((*editor-state* (%fresh-editor-state (format nil "one~%two"))))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 3)
        (loom::kill-line)
        (expect (buffer-text buffer) :to-equal "onetwo")
        (expect (first (editor-state-kill-ring *editor-state*))
                :to-equal (format nil "~%")))))

  (it
    "kill-line is a no-op at the very end of the buffer"
    (let ((*editor-state* (%fresh-editor-state "hi")))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 2)
        (loom::kill-line)
        (expect (buffer-text buffer) :to-equal "hi")
        (expect (editor-state-kill-ring *editor-state*) :to-be nil))))

  (it
    "kill-region reports no active region when the mark is unset"
    (%with-minibuffer-state (minibuffer "hello")
      (loom::kill-region)
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal "The mark is not set now, so no region is active")))

  (it
    "kill-region kills forward from point to mark"
    (let ((*editor-state* (%fresh-editor-state "hello world")))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 0)
        (buffer-set-mark buffer 0 5)
        (loom::kill-region)
        (expect (buffer-line buffer 0) :to-equal " world")
        (expect (first (editor-state-kill-ring *editor-state*)) :to-equal "hello"))))

  (it
    "kill-region kills backward from mark to point"
    (let ((*editor-state* (%fresh-editor-state "hello world")))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-mark buffer 0 0)
        (buffer-set-point buffer 0 5)
        (loom::kill-region)
        (expect (buffer-line buffer 0) :to-equal " world")
        (expect (first (editor-state-kill-ring *editor-state*)) :to-equal "hello"))))

  (it
    "kill-region spans multiple lines when point and mark are on different lines"
    (let ((*editor-state* (%fresh-editor-state (format nil "one~%two~%three"))))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 0)
        (buffer-set-mark buffer 2 0)
        (loom::kill-region)
        (expect (buffer-text buffer) :to-equal "three"))))

  (it
    "kill-region spans multiple lines when point is on a later line than mark"
    (let ((*editor-state* (%fresh-editor-state (format nil "one~%two~%three"))))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-mark buffer 0 0)
        (buffer-set-point buffer 2 0)
        (loom::kill-region)
        (expect (buffer-text buffer) :to-equal "three"))))

  )
