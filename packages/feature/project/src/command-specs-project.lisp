(in-package #:loom/core/command)
(register-command-spec :feature/project "project-find-file" "project-find-file" #'loom/feature/project:project-find-file
  :keys '(((:control #\x) #\p #\f))
  :keymap :global :group "files and projects" :help nil :help-order nil
  :mutates nil :prompts '(:completion) :needs-region nil :external '() :modes '(:all))
(register-command-spec :feature/project "project-search" "project-search" #'loom/feature/project:project-search
  :keys '(((:control #\x) #\p #\s))
  :keymap :global :group "files and projects" :help nil :help-order nil
  :mutates nil :prompts '(:free-string) :needs-region nil :external '() :modes '(:all))
(register-command-spec :feature/project "project-root" "project-root" #'loom/feature/project:project-root
  :keys '(((:control #\x) #\p #\r))
  :keymap :global :group "files and projects" :help nil :help-order nil
  :mutates nil :prompts '() :needs-region nil :external '() :modes '(:all))
