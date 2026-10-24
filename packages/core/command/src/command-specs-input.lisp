(in-package #:loom/core/command)

(register-command-spec :core/command "keyboard-quit" "keyboard-quit" #'loom::keyboard-quit
  :keys '((:control #\g)) :keymap :global :group "ui and lifecycle" :help nil :help-order nil
  :mutates nil :prompts '() :needs-region nil :external '() :modes '(:all))
