(in-package #:loom/core/command)
(register-command-spec :feature/auto-save "auto-save-mode" "auto-save-mode" #'loom/feature/auto-save:auto-save-mode
  :keys '() :keymap :global :group "files and projects" :help nil :help-order nil
  :mutates nil :prompts '() :needs-region nil :external '() :modes '(:all))
(register-command-spec :feature/auto-save "toggle-auto-save" "toggle-auto-save" #'loom/feature/auto-save:toggle-auto-save
  :keys '() :keymap :global :group "files and projects" :help nil :help-order nil
  :mutates nil :prompts '() :needs-region nil :external '() :modes '(:all))
(register-command-spec :feature/auto-save "auto-save-current-buffer" "auto-save-current-buffer" #'loom/feature/auto-save:auto-save-current-buffer
  :keys '() :keymap :global :group "files and projects" :help nil :help-order nil
  :mutates nil :prompts '() :needs-region nil :external '() :modes '(:all))
