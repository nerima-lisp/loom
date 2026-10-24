(in-package #:loom/core/command)
(register-command-spec :feature/lsp "lsp-completion-at-point" "lsp-completion-at-point" #'loom/feature/lsp:lsp-completion-at-point
  :keys '((:control :alt #\i)) :keymap :global :group "tooling" :help nil :help-order nil
  :mutates nil :prompts '() :needs-region nil :external '("lsp-server") :modes '(:all))
