;;;; t/integration/commands-editing-buffer-mutation-test.lisp
;;;;
;;;; Buffer mutation command integration tests.
(in-package #:loom/test)

(describe
  "editing commands"
  (it-each
      (("self-insert-command inserts the typed character at point"
        "hllo" 1 :self-insert
        "hello")
       ("delete-char deletes the character at point"
        "hello" 0 :delete-char
        "ello")
       ("delete-backward-char deletes the character before point"
        "hello" 5 :delete-backward-char
        "hell"))
      "~A" (label initial-content column operation-kind expected-line)
    (%with-selected-buffer-state (buffer initial-content)
      (buffer-set-point buffer 0 column)
      (ecase operation-kind
        (:self-insert (loom:self-insert-command #\e))
        (:delete-char (loom::delete-char))
        (:delete-backward-char (loom::delete-backward-char)))
      (expect (buffer-line buffer 0) :to-equal expected-line)))

  (it "does not insert or open lines for a zero prefix"
    (let ((*editor-state* (%fresh-editor-state "hello"))
          (loom:*current-prefix-argument* 0))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 2)
        (loom:self-insert-command #\x)
        (loom::newline-command)
        (loom::open-line)
        (expect (buffer-text buffer) :to-equal "hello")
        (expect buffer :to-have-point (cons 0 2))))))
