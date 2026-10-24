(in-package #:loom/core/command)
(register-command-spec :feature/mode "set-major-mode" "set-major-mode" #'loom/feature/mode:set-major-mode
  :keys '() :keymap :global :group "files and projects" :help nil :help-order nil
  :mutates nil :prompts '(:completion) :needs-region nil :external '() :modes '(:all))
(register-command-spec :feature/mode "toggle-truncate-lines" "toggle-truncate-lines" #'loom/feature/mode:toggle-truncate-lines
  :keys '() :keymap :global :group "files and projects" :help nil :help-order nil
  :mutates nil :prompts '() :needs-region nil :external '() :modes '(:all))
