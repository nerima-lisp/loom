(in-package #:loom/core/command)
(register-command-spec :feature/register "copy-to-register" "copy-to-register" #'loom/feature/register:copy-to-register
  :keys '(((:control #\x) #\r #\s)) :keymap :global :group "session and registers" :help "C-x r s Copy region to register" :help-order 23
  :mutates nil :prompts '(:free-string) :needs-region t :external '() :modes '(:all))
(register-command-spec :feature/register "insert-register" "insert-register" #'loom/feature/register:insert-register
  :keys '(((:control #\x) #\r #\i)) :keymap :global :group "session and registers" :help "C-x r i Insert register" :help-order 24
  :mutates t :prompts '(:free-string) :needs-region nil :external '() :modes '(:all))
(register-command-spec :feature/register "point-to-register" "point-to-register" #'loom/feature/register:point-to-register
  :keys '(((:control #\x) #\r #\Space)) :keymap :global :group "session and registers" :help "C-x r SPC Point to register" :help-order 25
  :mutates nil :prompts '(:free-string) :needs-region nil :external '() :modes '(:all))
(register-command-spec :feature/register "jump-to-register" "jump-to-register" #'loom/feature/register:jump-to-register
  :keys '(((:control #\x) #\r #\j)) :keymap :global :group "session and registers" :help "C-x r j Jump to register" :help-order 26
  :mutates nil :prompts '(:free-string) :needs-region nil :external '() :modes '(:all))
