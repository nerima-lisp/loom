(in-package #:loom/core/command)
(register-command-spec :feature/help "help" "help" #'loom::help-command
  :keys '((:control #\h) :f1) :keymap :global :group "ui and lifecycle" :help nil :help-order nil
  :mutates nil :prompts '() :needs-region nil :external '() :modes '(:all))
