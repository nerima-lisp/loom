(in-package #:loom)

(define-command-spec-groups *editing-command-spec-groups*
  (command-spec-group "editing"
      (command-spec "delete-char" delete-char :keys ((:control #\d))
                    :mutates T
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "delete-backward-char" delete-backward-char
                    :keys (:backspace)
                    :mutates T
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "newline" newline-command :keys (:enter)
                    :mutates T
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "open-line" open-line :keys ((:control #\o))
                    :mutates T
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "kill-line" kill-line
                    :keys ((:control #\k))
                    :help "C-k Cut"
                    :help-order 31
                    :mutates T
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "kill-word" kill-word :keys ((:alt #\d))
                    :mutates T
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "backward-kill-word" backward-kill-word
                    :keys ((:alt :backspace))
                    :mutates T
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "indent-for-tab-command"
                    loom/feature/mode:indent-for-tab-command
                    :keys (:tab)
                    :mutates T
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "comment-line" loom/feature/mode:comment-line
                    :keys ((:alt #\;))
                    :mutates T
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:common-lisp :python :rust :shell :emacs-lisp :nix :typescript :typescript-react :markdown :org))
      (command-spec "kill-region" kill-region :keys ((:control #\w))
                    :mutates T
                    :prompts NIL
                    :needs-region T
                    :external NIL
                    :modes (:all))
      (command-spec "kill-ring-save" kill-ring-save
                    :keys ((:alt #\w))
                    :help "M-w Copy"
                    :help-order 32
                    :mutates NIL
                    :prompts NIL
                    :needs-region T
                    :external NIL
                    :modes (:all))
      (command-spec "yank" yank :keys ((:control #\y))
                    :help "C-y Paste"
                    :help-order 33
                    :mutates T
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "yank-pop" yank-pop :keys ((:alt #\y))
                    :help "M-y Yank previous"
                    :help-order 36
                    :mutates T
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "set-mark-command" set-mark-command
                    :keys ((:control #\Space))
                    :mutates NIL
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "exchange-point-and-mark" exchange-point-and-mark
                    :keys (((:control #\x) (:control #\x)))
                    :mutates NIL
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "mark-whole-buffer" mark-whole-buffer
                    :keys (((:control #\x) #\h))
                    :mutates NIL
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "narrow-to-region" narrow-to-region
                    :keys (((:control #\x) #\n #\n))
                    :mutates NIL
                    :prompts NIL
                    :needs-region T
                    :external NIL
                    :modes (:all))
      (command-spec "widen" widen
                    :keys (((:control #\x) #\n #\w))
                    :mutates NIL
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "toggle-read-only" toggle-read-only
                    :keys (((:control #\x) (:control #\q)))
                    :mutates NIL
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "undo" undo-command
                    :keys (((:control #\x) (:control #\u)))
                    :help "C-x C-u Undo"
                    :help-order 34
                    :mutates T
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "redo" redo-command
                    :keys (((:control #\x) (:control #\y)))
                    :help "C-x C-y Redo"
                    :help-order 35
                    :mutates T
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "isearch-forward" loom/feature/search:isearch-forward
                    :keys ((:control #\s))
                    :help "C-s Find"
                    :help-order 30
                    :mutates NIL
                    :prompts (:free-string)
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "isearch-backward" loom/feature/search:isearch-backward
                    :keys ((:control #\r))
                    :mutates NIL
                    :prompts (:free-string)
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "search-forward" loom/feature/search:search-forward
                    :mutates NIL
                    :prompts (:free-string)
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "search-backward" loom/feature/search:search-backward
                    :mutates NIL
                    :prompts (:free-string)
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "replace-string" loom/feature/search:replace-string
                    :keys ((:alt #\%))
                    :mutates T
                    :prompts (:free-string :free-string)
                    :needs-region NIL
                    :external NIL
                    :modes (:all))))
