(in-package #:loom/core/command)
(register-command-spec :feature/workspace "new-workspace" "new-workspace" #'loom/feature/workspace:new-workspace
  :keys '(((:control #\x) #\t #\2)) :keymap :global :group "windows and workspaces" :help nil :help-order nil
  :mutates nil :prompts '() :needs-region nil :external '() :modes '(:all))
(register-command-spec :feature/workspace "switch-workspace" "switch-workspace" #'loom/feature/workspace:switch-workspace
  :keys '(((:control #\x) #\t #\o)) :keymap :global :group "windows and workspaces" :help nil :help-order nil
  :mutates nil :prompts '(:completion) :needs-region nil :external '() :modes '(:all))
(register-command-spec :feature/workspace "kill-workspace" "kill-workspace" #'loom/feature/workspace:kill-workspace
  :keys '(((:control #\x) #\t #\k)) :keymap :global :group "windows and workspaces" :help nil :help-order nil
  :mutates nil :prompts '() :needs-region nil :external '() :modes '(:all))
(register-command-spec :feature/workspace "next-workspace" "next-workspace" #'loom/feature/workspace:next-workspace
  :keys '(((:control #\x) #\t #\n)) :keymap :global :group "windows and workspaces" :help nil :help-order nil
  :mutates nil :prompts '() :needs-region nil :external '() :modes '(:all))
(register-command-spec :feature/workspace "previous-workspace" "previous-workspace" #'loom/feature/workspace:previous-workspace
  :keys '(((:control #\x) #\t #\p)) :keymap :global :group "windows and workspaces" :help nil :help-order nil
  :mutates nil :prompts '() :needs-region nil :external '() :modes '(:all))
