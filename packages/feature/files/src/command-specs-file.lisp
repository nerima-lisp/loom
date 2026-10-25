(in-package #:loom/core/command)

(progn
  (register-command-spec :feature/files "find-file" "find-file" #'loom/feature/files:find-file
                       :keys '(((:control #\x) (:control #\f)))
                       :keymap :global
                       :group "files and projects"
                       :help "C-x C-f Open"
                       :help-order 15
                       :mutates nil
                       :prompts '(:free-string)
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  (register-command-spec :feature/files "recent-file" "recent-file" #'loom/feature/files:recent-file
                       :keys '(((:control #\x) #\r #\f))
                       :keymap :global
                       :group "files and projects"
                       :help "C-x r f Recent file"
                       :help-order 19
                       :mutates nil
                       :prompts '(:completion)
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  )
