(in-package #:loom/core/command)
(register-command-spec :feature/buffers "switch-to-buffer" "switch-to-buffer" #'loom/feature/buffers:switch-to-buffer
  :keys '(((:control #\x) #\b)) :keymap :global :group "windows and workspaces" :help nil :help-order nil
  :mutates nil :prompts '(:completion) :needs-region nil :external '() :modes '(:all))
(register-command-spec :feature/buffers "kill-buffer" "kill-buffer" #'loom/feature/buffers:kill-buffer
  :keys '(((:control #\x) #\k)) :keymap :global :group "windows and workspaces" :help nil :help-order nil
  :mutates nil :prompts '(:completion :free-string) :needs-region nil :external '() :modes '(:all))
