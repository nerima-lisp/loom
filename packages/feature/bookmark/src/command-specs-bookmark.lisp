(in-package #:loom/core/command)
(register-command-spec :feature/bookmark "set-bookmark" "set-bookmark" #'loom/feature/bookmark::set-bookmark
  :keys '(((:control #\x) #\r #\m)) :keymap :global :group "session and registers" :help "C-x r m Set bookmark" :help-order 20
  :mutates nil :prompts '(:free-string) :needs-region nil :external '() :modes '(:all))
(register-command-spec :feature/bookmark "jump-to-bookmark" "jump-to-bookmark" #'loom/feature/bookmark::jump-to-bookmark
  :keys '(((:control #\x) #\r #\b)) :keymap :global :group "session and registers" :help "C-x r b Jump bookmark" :help-order 21
  :mutates nil :prompts '(:completion) :needs-region nil :external '() :modes '(:all))
(register-command-spec :feature/bookmark "delete-bookmark" "delete-bookmark" #'loom/feature/bookmark::delete-bookmark
  :keys '(((:control #\x) #\r #\d)) :keymap :global :group "session and registers" :help "C-x r d Delete bookmark" :help-order 22
  :mutates nil :prompts '(:completion) :needs-region nil :external '() :modes '(:all))
(register-command-spec :feature/bookmark "list-bookmarks" "list-bookmarks" #'loom/feature/bookmark::list-bookmarks
  :keys '(((:control #\x) #\r #\l)) :keymap :global :group "session and registers" :help nil :help-order nil
  :mutates nil :prompts '() :needs-region nil :external '() :modes '(:all))
