(in-package #:loom/core/command)
(register-command-spec :feature/session "save-session" "save-session" #'loom/feature/session:save-session
  :keys '(((:control #\x) #\r #\S)) :keymap :global :group "session and registers" :help "C-x r S Save session" :help-order 17
  :mutates nil :prompts '(:free-string) :needs-region nil :external '() :modes '(:all))
(register-command-spec :feature/session "load-session" "load-session" #'loom/feature/session:load-session
  :keys '() :keymap :global :group "session and registers" :help nil :help-order nil
  :mutates t :prompts '(:free-string) :needs-region nil :external '() :modes '(:all))
