(in-package #:loom/core/command)

(register-command-spec :core/command "execute-extended-command" nil 'loom::execute-extended-command
  :keys '((:alt #\x)) :keymap :global :group "ui and lifecycle" :help "M-x Command" :help-order 1
  :mutates nil :prompts '(:completion) :needs-region nil :external '() :modes '(:all))
