(in-package #:loom/core/command)
(register-command-spec :feature/lsp "lsp-start" "lsp-start" #'loom/feature/lsp:lsp-start
  :keys '() :keymap :global :group "tooling" :help "M-x lsp-start" :help-order 11
  :mutates nil :prompts '(:free-string :yes-no) :needs-region nil :external '("lsp-server") :modes '(:all))
(register-command-spec :feature/lsp "lsp-stop" "lsp-stop" #'loom/feature/lsp:lsp-stop
  :keys '() :keymap :global :group "tooling" :help "M-x lsp-stop" :help-order 12
  :mutates nil :prompts '() :needs-region nil :external '("lsp-server") :modes '(:all))
(register-command-spec :feature/lsp "lsp-diagnostics" "lsp-diagnostics" #'loom/feature/lsp:lsp-diagnostics
  :keys '() :keymap :global :group "tooling" :help "M-x lsp-diagnostics" :help-order 13
  :mutates nil :prompts '() :needs-region nil :external '("lsp-server") :modes '(:all))
