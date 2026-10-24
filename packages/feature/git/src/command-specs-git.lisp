(in-package #:loom/core/command)
(register-command-spec :feature/git "git-status" "git-status" #'loom/feature/git:git-status
  :keys '((( :control #\x) #\g))
  :keymap :global :group "tooling" :help "C-x g Git status" :help-order 5
  :mutates nil :prompts '() :needs-region nil :external '("git") :modes '(:all))
(register-command-spec :feature/git "git-diff" "git-diff" #'loom/feature/git:git-diff
  :keys '() :keymap :global :group "tooling" :help "M-x git-diff" :help-order 6
  :mutates nil :prompts '() :needs-region nil :external '("git") :modes '(:all))
(register-command-spec :feature/git "git-diff-staged" "git-diff-staged" #'loom/feature/git:git-diff-staged
  :keys '() :keymap :global :group "tooling" :help "M-x git-diff-staged" :help-order 7
  :mutates nil :prompts '() :needs-region nil :external '("git") :modes '(:all))
(register-command-spec :feature/git "git-stage-file" "git-stage-file" #'loom/feature/git:git-stage-file
  :keys '() :keymap :global :group "tooling" :help "M-x git-stage-file" :help-order 8
  :mutates nil :prompts '(:free-string) :needs-region nil :external '("git") :modes '(:all))
(register-command-spec :feature/git "git-unstage-file" "git-unstage-file" #'loom/feature/git:git-unstage-file
  :keys '() :keymap :global :group "tooling" :help "M-x git-unstage-file" :help-order 9
  :mutates nil :prompts '(:free-string) :needs-region nil :external '("git") :modes '(:all))
