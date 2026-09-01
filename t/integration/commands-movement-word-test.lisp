(in-package #:loom/test)

(describe
  "word motion helper definition"
  (it
    "expands a helper into a zero-argument visible-buffer operation"
    (let ((expansion
            (macroexpand-1
             '(loom::define-word-motion-helper test-word-motion test-offset))))
      (expect (first expansion) :to-be 'defun)
      (expect (second expansion) :to-be 'test-word-motion)
      (expect (third expansion) :to-equal '())
      (expect (first (fourth expansion)) :to-be 'let*))))

(describe
  "movement commands word and buffer motion"
  (it
    "moves by words and reaches both buffer boundaries"
    (let ((*editor-state* (%fresh-editor-state "one two")))
      (let ((buffer (%selected-test-buffer)))
        (loom::forward-word)
        (expect buffer :to-have-point (cons 0 3))
        (loom::forward-word)
        (expect buffer :to-have-point (cons 0 7))
        (loom::beginning-of-buffer)
        (expect buffer :to-have-point (cons 0 0))
        (loom::end-of-buffer)
        (expect buffer :to-have-point (cons 0 7)))))

  (it
    "moves backward by words to the beginning of each previous word"
    (let ((*editor-state* (%fresh-editor-state "one, two")))
      (let ((buffer (%selected-test-buffer)))
        (loom::end-of-buffer)
        (loom::backward-word)
        (expect buffer :to-have-point (cons 0 5))
        (loom::backward-word)
        (expect buffer :to-have-point (cons 0 0))))))
