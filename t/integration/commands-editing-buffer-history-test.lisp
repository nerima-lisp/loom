;;;; t/integration/commands-editing-buffer-history-test.lisp
;;;;
;;;; Buffer history command integration tests.
(in-package #:loom/test)

(describe
  "undo-command"
  (it
    "undoes the most recent edit in the selected buffer"
    (%with-selected-buffer-state (buffer "hello")
      (buffer-set-point buffer 0 5)
      (buffer-insert-string buffer "!")
      (expect (buffer-line buffer 0) :to-equal "hello!")
      (loom::undo-command)
      (expect (buffer-line buffer 0) :to-equal "hello"))))

(describe
  "redo-command"
  (it
    "redoes the most recent undone edit in the selected buffer"
    (%with-selected-buffer-state (buffer "hello")
      (buffer-set-point buffer 0 5)
      (buffer-insert-string buffer "!")
      (loom::undo-command)
      (loom::redo-command)
      (expect (buffer-line buffer 0) :to-equal "hello!"))))
