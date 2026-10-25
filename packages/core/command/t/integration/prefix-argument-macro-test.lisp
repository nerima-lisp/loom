(in-package #:loom/test)

(describe
  "prefix argument command definitions"
  (it
    "expands a nonnegative prefix binding around its body"
    (let ((expansion
            (macroexpand-1
             '(loom::with-nonnegative-command-prefix (count)
                (list count)))))
      (expect (first expansion) :to-be 'let)
      (expect (symbol-name (first (first (second expansion)))) :to-equal "COUNT")
      (expect (first (second (first (second expansion)))) :to-be 'max)
      (expect (first (third expansion)) :to-be 'list)))
  (it
    "expands a repeating command with prefix-aware dispatch"
    (let ((expansion
            (macroexpand-1
             '(loom::define-repeating-command test-repeat
                  "test documentation"
                  forward-command backward-command
                ))))
      (expect (first expansion) :to-be 'defun)
      (expect (second expansion) :to-be 'test-repeat)
      (expect (third expansion) :to-equal '())
      (expect (fourth expansion) :to-equal "test documentation")
      (expect (first (fifth expansion)) :to-be 'loom::%repeat-command))))
