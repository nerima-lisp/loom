(in-package #:loom/core/command)
(register-command-spec :feature/lifecycle "save-buffers-kill-terminal" "save-buffers-kill-terminal" #'loom::save-buffers-kill-terminal
  :keys '(((:control #\x) (:control #\c))) :keymap :global :group "ui and lifecycle" :help "C-x C-c Exit" :help-order 37
  :mutates nil :prompts '(:free-string) :needs-region nil :external '() :modes '(:all))
