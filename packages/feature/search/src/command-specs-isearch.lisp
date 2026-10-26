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
  (register-command-spec :feature/search "isearch-forward-regexp" "isearch-forward-regexp" #'loom/feature/search::isearch-forward-regexp
                       :keys '((:control :alt #\s))
                       :keymap :global
                       :group "editing"
                       :help "C-M-s Find by Regexp"
                       :help-order 31
                       :mutates nil
                       :prompts '(:free-string)
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  (register-command-spec :feature/search "isearch-backward-regexp" "isearch-backward-regexp" #'loom/feature/search::isearch-backward-regexp
                       :keys '((:control :alt #\r))
                       :keymap :global
                       :group "editing"
                       :help "C-M-r Find by Regexp"
                       :help-order 32
                       :mutates nil
                       :prompts '(:free-string)
                       :needs-region nil
                       :external 'nil
                       :modes '(:all)))
