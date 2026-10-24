(in-package #:loom/core/command)
(register-command-spec :feature/lsp "lsp-find-definition" "lsp-find-definition" #'loom/feature/lsp:lsp-find-definition
  :keys '((:alt #\.)) :keymap :global :group "tooling" :help nil :help-order nil
  :mutates nil :prompts '() :needs-region nil :external '("lsp-server") :modes '(:all))
(register-command-spec :feature/lsp "lsp-pop-definition" "lsp-pop-definition" #'loom/feature/lsp:lsp-pop-definition
  :keys '((:alt #\,)) :keymap :global :group "tooling" :help nil :help-order nil
  :mutates nil :prompts '() :needs-region nil :external '() :modes '(:all))
