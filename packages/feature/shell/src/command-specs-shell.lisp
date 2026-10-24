(in-package #:loom/core/command)
(register-command-spec :feature/shell "pipe-command" "pipe-command" #'loom/feature/shell:pipe-command
  :keys '((:alt #\!))
  :keymap :global :group "tooling" :help "M-! Pipe command" :help-order 4
  :mutates nil :prompts '(:free-string) :needs-region nil :external '("shell") :modes '(:all))
