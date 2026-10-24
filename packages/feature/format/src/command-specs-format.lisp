(in-package #:loom/core/command)
(register-command-spec :feature/format "format-current-buffer" "format-current-buffer" #'loom/feature/format:format-current-buffer
  :keys '() :keymap :global :group "tooling" :help "M-x format-current-buffer" :help-order 10
  :mutates t :prompts '(:free-string) :needs-region nil :external '("shell") :modes '(:all))
(register-command-spec :feature/format "format-on-save-mode" "format-on-save-mode" #'loom/feature/format:format-on-save-mode
  :keys '() :keymap :global :group "tooling" :help nil :help-order nil
  :mutates nil :prompts '() :needs-region nil :external '() :modes '(:all))
(register-command-spec :feature/format "set-format-command" "set-format-command" #'loom/feature/format:set-format-command-command
  :keys '() :keymap :global :group "tooling" :help nil :help-order nil
  :mutates nil :prompts '(:free-string) :needs-region nil :external '() :modes '(:all))
