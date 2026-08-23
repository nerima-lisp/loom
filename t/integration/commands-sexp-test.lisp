;;;; t/integration/commands-sexp-test.lisp
;;;;
;;;; Structural motion commands and their default C-M- bindings.
(in-package #:loom/test)

(describe
  "structural motion commands"
  (it
    "forward-sexp steps over a list and then over the atom after it"
    (%with-selected-buffer-state (buffer "(a b) c")
      (buffer-set-point buffer 0 0)
      (loom::forward-sexp)
      (expect (buffer-point-column buffer) :to-equal 5)
      (loom::forward-sexp)
      (expect (buffer-point-column buffer) :to-equal 7)))

  (it
    "forward-sexp leaves point alone at a closing parenthesis"
    (%with-selected-buffer-state (buffer "(a b)")
      (buffer-set-point buffer 0 4)
      (loom::forward-sexp)
      (expect (buffer-point-column buffer) :to-equal 4)))

  (it
    "backward-sexp returns to the start of the expression before point"
    (%with-selected-buffer-state (buffer "(a b) c")
      (buffer-set-point buffer 0 7)
      (loom::backward-sexp)
      (expect (buffer-point-column buffer) :to-equal 6)
      (loom::backward-sexp)
      (expect (buffer-point-column buffer) :to-equal 0)))

  (it
    "backward-up-list and down-list cross the enclosing parentheses"
    (%with-selected-buffer-state (buffer "(a (b c) d)")
      (buffer-set-point buffer 0 5)
      (loom::backward-up-list)
      (expect (buffer-point-column buffer) :to-equal 3)
      (loom::backward-up-list)
      (expect (buffer-point-column buffer) :to-equal 0)
      (loom::down-list)
      (expect (buffer-point-column buffer) :to-equal 1)))

  (it
    "steps over a parenthesis that is only text"
    (%with-selected-buffer-state (buffer "(a \"(\" b) c")
      (buffer-set-point buffer 0 0)
      (loom::forward-sexp)
      (expect (buffer-point-column buffer) :to-equal 9)))

  (it
    "crosses lines, counting a comment's parenthesis as text"
    (%with-selected-buffer-state (buffer (format nil "(a ; )~%   b)~%c"))
      (buffer-set-point buffer 0 0)
      (loom::forward-sexp)
      (expect buffer :to-have-point (cons 1 5))))

  (it
    "kill-sexp puts the expression on the kill ring and coalesces repeats"
    (%with-selected-buffer-state (buffer "(a b) (c d) e")
      (buffer-set-point buffer 0 0)
      (loom::kill-sexp)
      (expect (buffer-text buffer) :to-equal " (c d) e")
      (expect (first (editor-state-kill-ring *editor-state*))
              :to-equal "(a b)")
      (loom::kill-sexp)
      (expect (buffer-text buffer) :to-equal " e")
      (expect (editor-state-kill-ring *editor-state*)
              :to-equal '("(a b) (c d)"))))

  (it
    "kill-sexp leaves the buffer alone when there is nothing to kill"
    (%with-selected-buffer-state (buffer "(a b)")
      (buffer-set-point buffer 0 4)
      (loom::kill-sexp)
      (expect (buffer-text buffer) :to-equal "(a b)")
      (expect (editor-state-kill-ring *editor-state*) :to-be nil))))

(describe
  "structural motion keybindings"
  (it-each
      (("C-M-f" (((:control :alt) . #\f)) loom::forward-sexp)
       ("C-M-b" (((:control :alt) . #\b)) loom::backward-sexp)
       ("C-M-u" (((:control :alt) . #\u)) loom::backward-up-list)
       ("C-M-d" (((:control :alt) . #\d)) loom::down-list)
       ("C-M-k" (((:control :alt) . #\k)) loom::kill-sexp))
      "binds ~A to its default command" (label key-sequence command)
    (declare (ignore label))
    (let ((keymap (make-keymap)))
      (loom/application:install-default-keybindings keymap)
      (expect (keymap-lookup keymap key-sequence) :to-be command)))

  (it
    "keeps an ESC-prefixed Ctrl-letter distinct from the bare chord"
    (expect (loom::%key-event->descriptor
             (cl-tty-kit:make-key-event :type :special :code :control-f))
            :to-equal '((:control) . #\f))
    (expect (loom::%key-event->descriptor
             (cl-tty-kit:make-key-event :type :special
                                        :code :control-f
                                        :modifiers '(:alt)))
            :to-equal '((:control :alt) . #\f))))
