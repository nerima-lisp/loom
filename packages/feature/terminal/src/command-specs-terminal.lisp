(in-package #:loom/core/command)
(register-command-spec :feature/terminal "terminal" "terminal" #'loom/feature/terminal:terminal
  :keys '() :keymap :global :group "tooling" :help nil :help-order nil
  :mutates nil :prompts '() :needs-region nil :external '("shell") :modes '(:all))
(register-command-spec :feature/terminal "terminal-stop" "terminal-stop" #'loom/feature/terminal:terminal-stop
  :keys '() :keymap :global :group "tooling" :help nil :help-order nil
  :mutates nil :prompts '() :needs-region nil :external '("shell") :modes '(:all))
