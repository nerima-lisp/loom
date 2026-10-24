(in-package #:loom/core/command)

(progn
  (register-command-spec :feature/search "isearch-forward" "isearch-forward" #'loom/feature/search:isearch-forward
                       :keys '((:control #\s))
                       :keymap :global
                       :group "editing"
                       :help "C-s Find"
                       :help-order 30
                       :mutates nil
                       :prompts '(:free-string)
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  (register-command-spec :feature/search "isearch-backward" "isearch-backward" #'loom/feature/search:isearch-backward
                       :keys '((:control #\r))
                       :keymap :global
                       :group "editing"
                       :help nil
                       :help-order nil
                       :mutates nil
                       :prompts '(:free-string)
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  )
