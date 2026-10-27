(in-package #:loom/test)
(describe
  "structural editing commands with C-u 4"
  (it-each
      ((loom::backward-barf-sexp "(a b)
" 1 "(a b)
" 1)
       (loom::backward-slurp-sexp "a (b)
" 3 "(a b)
" 3)
       (loom::forward-barf-sexp "(a b c d e)
" 1 "(a) b c d e
" 1)
       (loom::forward-slurp-sexp "(a) b
" 1 "(a b
   )" 1)
       (loom::raise-sexp "((a b c d e) z)
" 2 "(a b c d z)
" 1)
       (loom::splice-sexp "(a (b c) d)
" 4 "(a b c d)
" 3)
       (loom::wrap-round "a b
" 0 "(a b)
" 1))
      "C-u 4 ~S transforms ~S at ~D into ~S"
      (command content offset expected expected-column)
    (%with-selected-buffer-state (buffer content)
      (progn
        (buffer-set-major-mode buffer :common-lisp)
        (buffer-set-point buffer 0 offset))
      (let ((loom/core/command:*current-prefix-argument* 4))
        (funcall command))
      (expect (buffer-text buffer) :to-equal expected)
      (expect (buffer-point-column buffer) :to-equal expected-column))))
(describe
  "structural prefix argument from editor state"
  (it-each
    ((loom::forward-slurp-sexp "(a) b" 1)
     (loom::wrap-round "a b" 0)
     (loom::kill-sexp "a b" 0))
    "consumes the active universal argument after ~S"
    (command content offset)
    (let ((loom/core/command:*current-prefix-argument* nil))
      (%with-selected-buffer-state (buffer content)
        (buffer-set-major-mode buffer :common-lisp)
        (buffer-set-point buffer 0 offset)
        (loom::universal-argument)
        (let ((minibuffer
                (loom/core/editor-session:editor-state-minibuffer
                 loom/core/editor-session:*editor-state*)))
          (expect (loom::%structural-prefix-p) :to-be t)
          (expect (loom::%structural-prefix-count) :to-equal 4)
          (expect (loom:minibuffer-message-string minibuffer)
                  :to-equal "Prefix argument: 4")
          (funcall command)
          (expect (buffer-text buffer) :not :to-equal content)
          (expect (loom/core/command:prefix-argument-value-for-editor)
                  :to-equal 1)
          (expect (loom:minibuffer-message-string minibuffer)
                  :to-be nil)))))
  (it
    "defaults to one when no editor state is bound"
    (let ((loom/core/command:*current-prefix-argument* nil)
          (loom/core/editor-session:*editor-state* nil))
      (expect (loom::%structural-prefix-count) :to-equal 1))))

(describe
  "structural command definition"
  (it
    "expands a command into a zero-argument buffer operation"
    (let ((expansion
            (macroexpand-1
             '(loom::define-structural-command test-command
                "test documentation"
                test-edits))))
      (expect (first expansion) :to-be 'defun)
      (expect (second expansion) :to-be 'test-command)
      (expect (third expansion) :to-equal '())
      (expect (fourth expansion) :to-equal "test documentation")
      (expect (first (fifth expansion)) :to-be 'multiple-value-call))))

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

  (cl-weave:it-property
      "wrap-round preserves every generated atom inside a pair"
      ((length (cl-weave:gen-integer :min 0 :max 12))
       (character (cl-weave:gen-character :alphabet "abc")))
    (let ((content (make-string length :initial-element character)))
      (%with-selected-buffer-state (buffer content)
        (loom::wrap-round)
        (expect (buffer-text buffer)
                :to-equal (concatenate 'string "(" content ")"))
        (expect (buffer-point-column buffer) :to-equal 1))))

  (cl-weave:it-property
      "wrap-round skips generated filler before the first atom"
      ((filler-length (cl-weave:gen-integer :min 0 :max 8))
       (atom-length (cl-weave:gen-integer :min 1 :max 12))
       (character (cl-weave:gen-character :alphabet "abc")))
    (let ((filler (make-string filler-length :initial-element #\Space))
          (atom (make-string atom-length :initial-element character)))
      (%with-selected-buffer-state (buffer (concatenate 'string filler atom))
        (loom::wrap-round)
        (expect (buffer-text buffer)
                :to-equal (concatenate 'string filler "(" atom ")")))))

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

  (it
    "applies a slurp across a newline using buffer positions"
    (%with-selected-buffer-state (buffer "(a)\nb")
      (buffer-set-point buffer 0 1)
      (loom::forward-slurp-sexp)
      (expect (buffer-text buffer) :to-equal "(a\nb)")
      (expect (buffer-point-line buffer) :to-equal 0)
      (expect (buffer-point-column buffer) :to-equal 1)))

  (it-each
      ((loom::forward-slurp-sexp "(alpha)
  beta" 2 "(alpha
  beta)")
       (loom::forward-barf-sexp "(alpha
  beta)" 2 "(alpha)
  beta")
       (loom::backward-barf-sexp "(alpha
  beta)" 2 "alpha
  (beta)"))
      "~S preserves multiline structural edits for ~S"
      (command content offset expected)
    (%with-selected-buffer-state (buffer content)
      (buffer-set-point buffer 0 offset)
      (funcall command)
      (expect (buffer-text buffer) :to-equal expected)))

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
      (expect (buffer-text buffer) :to-equal content)))
  (it-each
      ((loom::forward-slurp-sexp "(a) b
" 1 1 0)
       (loom::forward-barf-sexp "(a b)
" 1 1 0)
       (loom::backward-slurp-sexp "a (b)
" 3 1 0)
       (loom::backward-barf-sexp "(a b)
" 1 0 0)
       (loom::splice-sexp "(a (b) c)
" 4 1 0)
       (loom::raise-sexp "(a (b) c)
" 4 1 0)
       (loom::wrap-round "a b
" 0 1 0))
      "~S restores the Emacs undo point"
      (command content offset expected-line expected-column)
    (%with-selected-buffer-state (buffer content)
      (buffer-set-point buffer 0 offset)
      (buffer-record-undo-boundary buffer)
      (funcall command)
      (buffer-undo buffer)
      (expect (buffer-text buffer) :to-equal content)
      (expect (buffer-point-line buffer) :to-equal expected-line)
      (expect (buffer-point-column buffer) :to-equal expected-column)))
  (it-each
      ((loom::forward-slurp-sexp "(a) b" 1)
       (loom::forward-barf-sexp "(a b)" 1)
       (loom::backward-slurp-sexp "a (b)" 3)
       (loom::backward-barf-sexp "(a b)" 1)
       (loom::splice-sexp "(a (b c) d)" 4)
       (loom::raise-sexp "(a (b c) d)" 3)
       (loom::wrap-round "a b" 0))
      "rejects read-only edits with the Emacs message before changing text"
      (command content offset)
    (%with-selected-buffer-state (buffer content)
      (buffer-set-point buffer 0 offset)
      (buffer-set-read-only buffer t)
      (let ((message
              (handler-case
                  (progn (funcall command) nil)
                (error (condition) (format nil "~A" condition)))))
        (expect message :to-equal
                (format nil "Buffer is read-only: #<buffer ~A>"
                        (buffer-name buffer))))
      (expect (buffer-text buffer) :to-equal content)
      (expect (buffer-point-column buffer) :to-equal offset))))

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
      "binds ~A in both Lisp mode-local maps, but not the global map"
      (label key-sequence command)
    (declare (ignore label))
    (let* ((global-keymap (make-keymap))
           (command-id
             (loom/core/command:command-id-for-function command)))
      (loom/application:install-default-keybindings global-keymap)
      (expect (keymap-lookup global-keymap key-sequence) :to-be nil)
      (dolist (mode (list :common-lisp :emacs-lisp))
        (let ((mode-keymap
                (loom/feature/mode:major-mode-keymap mode global-keymap)))
          (multiple-value-bind (binding owner)
              (keymap-lookup mode-keymap key-sequence)
            (expect binding :to-equal command-id)
            (expect owner :to-be mode-keymap)))))))
