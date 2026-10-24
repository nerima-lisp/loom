(in-package #:loom/core/command)
(register-command-spec :feature/window "split-window-below" "split-window-below" #'loom/feature/window:split-window-below
  :keys '(((:control #\x) #\2)) :keymap :global :group "windows and workspaces" :help nil :help-order nil
  :mutates nil :prompts '() :needs-region nil :external '() :modes '(:all))
(register-command-spec :feature/window "split-window-right" "split-window-right" #'loom/feature/window:split-window-right
  :keys '(((:control #\x) #\3)) :keymap :global :group "windows and workspaces" :help nil :help-order nil
  :mutates nil :prompts '() :needs-region nil :external '() :modes '(:all))
(register-command-spec :feature/window "other-window" "other-window" #'loom/feature/window:other-window
  :keys '(((:control #\x) #\o)) :keymap :global :group "windows and workspaces" :help nil :help-order nil
  :mutates nil :prompts '() :needs-region nil :external '() :modes '(:all))
(register-command-spec :feature/window "delete-window" "delete-window" #'loom/feature/window:delete-window
  :keys '(((:control #\x) #\0)) :keymap :global :group "windows and workspaces" :help nil :help-order nil
  :mutates nil :prompts '() :needs-region nil :external '() :modes '(:all))
(register-command-spec :feature/window "delete-other-windows" "delete-other-windows" #'loom/feature/window:delete-other-windows
  :keys '(((:control #\x) #\1)) :keymap :global :group "windows and workspaces" :help nil :help-order nil
  :mutates nil :prompts '() :needs-region nil :external '() :modes '(:all))
