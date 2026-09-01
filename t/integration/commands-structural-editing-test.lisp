;;;; t/integration/commands-structural-editing-test.lisp
;;;;
;;;; Structural editing commands against a real buffer: what they write, where
;;;; they leave point, that one command is one undo step, and their bindings.
(in-package #:loom/test)

(describe
  "structural command definition"
  (it
    "expands a command into a zero-argument buffer operation"
    (let ((expansion
            (macroexpand-1
             '(loom::define-structural-command test-command test-edits
                "test documentation"))))
      (expect (first expansion) :to-be 'defun)
      (expect (second expansion) :to-be 'test-command)
      (expect (third expansion) :to-equal '())
      (expect (fourth expansion) :to-equal "test documentation")
      (expect (first (fifth expansion)) :to-be 'multiple-value-bind))))

(describe
  "structural editing commands"
  (it-each
      ((loom::forward-slurp-sexp "(a) b" 1 "(a b)")
       (loom::forward-barf-sexp "(a b)" 1 "(a) b")
       (loom::backward-slurp-sexp "a (b)" 3 "(a b)")
       (loom::backward-barf-sexp "(a b)" 1 "a (b)")
       (loom::backward-barf-sexp "(a)" 1 "a ()")
       (loom::splice-sexp "(a (b c) d)" 4 "(a b c d)")
       (loom::raise-sexp "(a (b c) d)" 3 "(b c)")
       (loom::wrap-round "a b" 0 "(a) b"))
      "~S turns ~S at ~D into ~S"
      (command content offset expected)
    (%with-selected-buffer-state (buffer content)
      (buffer-set-point buffer 0 offset)
      (funcall command)
      (expect (buffer-text buffer) :to-equal expected)))

  (it-each
      ((loom::forward-slurp-sexp "(a)" 1)
       (loom::forward-barf-sexp "()" 1)
       (loom::backward-slurp-sexp "(b)" 1)
       (loom::splice-sexp "a b" 0)
       (loom::raise-sexp "a b" 0))
      "~S leaves ~S untouched when it has nothing to act on"
      (command content offset)
    (%with-selected-buffer-state (buffer content)
      (buffer-set-point buffer 0 offset)
      (funcall command)
      (expect (buffer-text buffer) :to-equal content)))

  (it
    "wrap-round inserts an empty pair and puts point inside it"
    (%with-selected-buffer-state (buffer "")
      (loom::wrap-round)
      (expect (buffer-text buffer) :to-equal "()")
      (expect (buffer-point-column buffer) :to-equal 1)))

  (it
    "wrap-round leaves point just inside the delimiter it added"
    (%with-selected-buffer-state (buffer "a b")
      (buffer-set-point buffer 0 0)
      (loom::wrap-round)
      (expect (buffer-text buffer) :to-equal "(a) b")
      (expect (buffer-point-column buffer) :to-equal 1)))

  (it
    "wrap-round inserts an empty pair before a closing delimiter"
    (%with-selected-buffer-state (buffer "(a)")
      (buffer-set-point buffer 0 2)
      (loom::wrap-round)
      (expect (buffer-text buffer) :to-equal "(a())")
      (expect (buffer-point-column buffer) :to-equal 3)))

  (it
    "keeps point on the same text through a slurp"
    (%with-selected-buffer-state (buffer "(a) b")
      (buffer-set-point buffer 0 1)
      (loom::forward-slurp-sexp)
      (expect (buffer-text buffer) :to-equal "(a b)")
      (expect (buffer-point-column buffer) :to-equal 1)))

  (it-each
      ((loom::forward-slurp-sexp "(a) b" 1)
       (loom::forward-barf-sexp "(a b)" 1)
       (loom::backward-slurp-sexp "a (b)" 3)
       (loom::backward-barf-sexp "(a b)" 1)
       (loom::splice-sexp "(a (b c) d)" 4)
       (loom::raise-sexp "(a (b c) d)" 3)
       (loom::wrap-round "a b" 0))
      "~S is a single undo step on ~S at ~D"
      (command content offset)
    (%with-selected-buffer-state (buffer content)
      (buffer-set-point buffer 0 offset)
      (buffer-record-undo-boundary buffer)
      (funcall command)
      (expect (buffer-text buffer) :not :to-equal content)
      (buffer-undo buffer)
      (expect (buffer-text buffer) :to-equal content))))

(describe
  "structural editing keybindings"
  (it-each
      (("C-<right>" (((:control) . :right)) loom::forward-slurp-sexp)
       ("C-<left>" (((:control) . :left)) loom::forward-barf-sexp)
       ("C-M-<left>" (((:control :alt) . :left)) loom::backward-slurp-sexp)
       ("C-M-<right>" (((:control :alt) . :right)) loom::backward-barf-sexp)
       ("M-(" (((:alt) . #\()) loom::wrap-round)
       ("M-s" (((:alt) . #\s)) loom::splice-sexp)
       ("M-r" (((:alt) . #\r)) loom::raise-sexp))
      "binds ~A to its default command" (label key-sequence command)
    (declare (ignore label))
    (let ((keymap (make-keymap)))
      (loom/application:install-default-keybindings keymap)
      (expect (keymap-lookup keymap key-sequence) :to-be command))))
