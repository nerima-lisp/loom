(in-package #:loom/core/command)

(progn
  (register-command-spec :feature/files "save-buffer" "save-buffer" #'loom/feature/files:save-buffer
                       :keys '(((:control #\x) (:control #\s)))
                       :keymap :global
                       :group "files and projects"
                       :help "C-x C-s Save"
                       :help-order 14
                       :mutates t
                       :prompts '(:free-string :yes-no)
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
  (register-command-spec :feature/files "revert-buffer" "revert-buffer" #'loom/feature/files:revert-buffer
                       :keys 'nil
                       :keymap :global
                       :group "files and projects"
                       :help "M-x revert-buffer"
                       :help-order 15
                       :mutates t
                       :prompts '(:yes-no)
                       :needs-region nil
                       :external 'nil
                       :modes '(:all)))
