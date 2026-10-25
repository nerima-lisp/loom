(in-package #:loom/core/command)

(progn
  (register-command-spec :feature/files "save-buffer" "save-buffer" #'loom/feature/files:save-buffer
                       :keys '(((:control #\x) (:control #\s)))
                       :keymap :global
                       :group "files and projects"
                       :help "C-x C-s Save"
                       :help-order 14
                       :mutates t
                       :prompts '(:free-string)
                       :needs-region nil
                       :external '("shell")
                       :modes '(:all))
  (register-command-spec :feature/files "write-file" "write-file" #'loom/feature/files:write-file
                       :keys '(((:control #\x) (:control #\w)))
                       :keymap :global
                       :group "files and projects"
                       :help nil
                       :help-order nil
                       :mutates nil
                       :prompts '(:free-string)
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  )
