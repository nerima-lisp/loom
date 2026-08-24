;;;; src/application/command-definitions-tooling.lisp
;;;;
;;;; Declarative command catalogue for tooling commands.
(in-package #:loom)

(define-command-spec-groups *tooling-command-spec-groups*
  (command-spec-group "tooling"
      (command-spec "pipe-command" loom/feature/shell:pipe-command
                    :keys ((:alt #\!))
                    :help "M-! Pipe command"
                    :help-order 4)
      (command-spec "terminal" loom/feature/terminal:terminal)
      (command-spec "terminal-stop" loom/feature/terminal:terminal-stop)
      (command-spec "git-status" loom/feature/git:git-status
                    :keys (((:control #\x) #\g))
                    :help "C-x g Git status"
                    :help-order 5)
      (command-spec "git-diff" loom/feature/git:git-diff
                    :help "M-x git-diff"
                    :help-order 6)
      (command-spec "git-diff-staged" loom/feature/git:git-diff-staged
                    :help "M-x git-diff-staged"
                    :help-order 7)
      (command-spec "git-stage-file" loom/feature/git:git-stage-file
                    :help "M-x git-stage-file"
                    :help-order 8)
      (command-spec "git-unstage-file" loom/feature/git:git-unstage-file
                    :help "M-x git-unstage-file"
                    :help-order 9)
      (command-spec "format-current-buffer"
                    loom/feature/format:format-current-buffer
                    :help "M-x format-current-buffer"
                    :help-order 10)
      (command-spec "format-on-save-mode"
                    loom/feature/format:format-on-save-mode)
      (command-spec "set-format-command"
                    loom/feature/format:set-format-command-command)
      (command-spec "lsp-start" loom/feature/lsp:lsp-start
                    :help "M-x lsp-start"
                    :help-order 11)
      (command-spec "lsp-stop" loom/feature/lsp:lsp-stop
                    :help "M-x lsp-stop"
                    :help-order 12)
      (command-spec "lsp-diagnostics" loom/feature/lsp:lsp-diagnostics
                    :help "M-x lsp-diagnostics"
                    :help-order 13)
      (command-spec "lsp-completion-at-point"
                    loom/feature/lsp:lsp-completion-at-point
                    :keys ((:control :alt #\i)))
      (command-spec "lsp-find-definition"
                    loom/feature/lsp:lsp-find-definition
                    :keys ((:alt #\.)))
      (command-spec "lsp-pop-definition"
                    loom/feature/lsp:lsp-pop-definition
                    :keys ((:alt #\,)))))
