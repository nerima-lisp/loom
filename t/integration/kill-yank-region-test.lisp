;;;; t/integration/kill-yank-region-test.lisp

(in-package #:loom/test)

(defmacro %expect-region-kill ((initial-content point mark expected-text expected-kill)
                               &body body)
  `(let ((*editor-state* (%fresh-editor-state ,initial-content)))
     (let ((buffer (%selected-test-buffer)))
       (buffer-set-point buffer 0 ,point)
       (buffer-set-mark buffer 0 ,mark)
       (loom::kill-region)
       (expect (buffer-text buffer) :to-equal ,expected-text)
       (expect (first (editor-state-kill-ring *editor-state*)) :to-equal ,expected-kill)
       ,@body)))

(describe
  "kill and yank commands"
  (it
    "keeps kill-line inside the narrowed region"
    (let ((*editor-state* (%fresh-editor-state "abCDEFgh")))
      (let ((buffer (%selected-test-buffer)))
        (buffer-narrow-to-region buffer 0 2 0 6)
        (buffer-set-point buffer 0 4)
        (loom::kill-line)
        (expect (buffer-text buffer) :to-equal "abCDgh")
        (expect (buffer-visible-text buffer) :to-equal "CD")
        (expect (first (editor-state-kill-ring *editor-state*)) :to-equal "EF"))))

  (it
    "copies a region without changing the buffer"
    (let ((*editor-state* (%fresh-editor-state "hello world")))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 0)
        (buffer-set-mark buffer 0 5)
        (loom::kill-ring-save)
        (expect (buffer-text buffer) :to-equal "hello world")
        (expect (first (editor-state-kill-ring *editor-state*)) :to-equal "hello")
        (expect (loom::editor-state-last-command-kill-p *editor-state*)
                :to-be-falsy))))

  (it
    "coalesces adjacent region kills in their editing direction"
    (%expect-region-kill ("abcdef" 0 2 "cdef" "ab")
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 0)
        (buffer-set-mark buffer 0 1)
        (loom::kill-region)
        (expect (buffer-text buffer) :to-equal "def")
        (expect (first (editor-state-kill-ring *editor-state*)) :to-equal "abc")))
    (%expect-region-kill ("abcdef" 0 2 "cdef" "ab")
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 1)
        (buffer-set-mark buffer 0 0)
        (loom::kill-region)
        (expect (buffer-text buffer) :to-equal "def")
        (expect (first (editor-state-kill-ring *editor-state*)) :to-equal "cab")))))
