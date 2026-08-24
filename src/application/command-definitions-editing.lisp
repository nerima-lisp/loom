;;;; src/application/command-definitions-editing.lisp
;;;;
;;;; Declarative command catalogue for editing commands.
(in-package #:loom)

(define-command-spec-groups *editing-command-spec-groups*
  (command-spec-group "editing"
      (command-spec "delete-char" delete-char :keys ((:control #\d)))
      (command-spec "delete-backward-char" delete-backward-char
                    :keys (:backspace))
      (command-spec "newline" newline-command :keys (:enter))
      (command-spec "open-line" open-line :keys ((:control #\o)))
      (command-spec "kill-line" kill-line
                    :keys ((:control #\k))
                    :help "C-k Cut"
                    :help-order 31)
      (command-spec "kill-word" kill-word :keys ((:alt #\d)))
      (command-spec "backward-kill-word" backward-kill-word
                    :keys ((:alt :backspace)))
      (command-spec "indent-for-tab-command"
                    loom/feature/mode:indent-for-tab-command
                    :keys (:tab))
      (command-spec "comment-line" loom/feature/mode:comment-line
                    :keys ((:alt #\;)))
      (command-spec "kill-region" kill-region :keys ((:control #\w)))
      (command-spec "kill-ring-save" kill-ring-save
                    :keys ((:alt #\w))
                    :help "M-w Copy"
                    :help-order 32)
      (command-spec "yank" yank :keys ((:control #\y))
                    :help "C-y Paste"
                    :help-order 33)
      (command-spec "yank-pop" yank-pop :keys ((:alt #\y))
                    :help "M-y Yank previous"
                    :help-order 36)
      (command-spec "set-mark-command" set-mark-command
                    :keys ((:control #\Space)))
      (command-spec "exchange-point-and-mark" exchange-point-and-mark
                    :keys (((:control #\x) (:control #\x))))
      (command-spec "mark-whole-buffer" mark-whole-buffer
                    :keys (((:control #\x) #\h)))
      (command-spec "narrow-to-region" narrow-to-region
                    :keys (((:control #\x) #\n #\n)))
      (command-spec "widen" widen
                    :keys (((:control #\x) #\n #\w)))
      (command-spec "toggle-read-only" toggle-read-only
                    :keys (((:control #\x) (:control #\q))))
      (command-spec "undo" undo-command
                    :keys (((:control #\x) (:control #\u)))
                    :help "C-x C-u Undo"
                    :help-order 34)
      (command-spec "redo" redo-command
                    :keys (((:control #\x) (:control #\y)))
                    :help "C-x C-y Redo"
                    :help-order 35)
      (command-spec "isearch-forward" loom/feature/search:isearch-forward
                    :keys ((:control #\s))
                    :help "C-s Find"
                    :help-order 30)
      (command-spec "isearch-backward" loom/feature/search:isearch-backward
                    :keys ((:control #\r)))
      (command-spec "search-forward" loom/feature/search:search-forward)
      (command-spec "search-backward" loom/feature/search:search-backward)
      (command-spec "replace-string" loom/feature/search:replace-string
                    :keys ((:alt #\%)))))
