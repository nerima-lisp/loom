(in-package #:loom/core/command)

(progn
  (register-command-spec :feature/search "search-forward" "search-forward" #'loom/feature/search:search-forward
                       :keys 'nil
                       :keymap :global
                       :group "editing"
                       :help nil
                       :help-order nil
                       :mutates nil
                       :prompts '(:free-string)
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  (register-command-spec :feature/search "search-backward" "search-backward" #'loom/feature/search:search-backward
                       :keys 'nil
                       :keymap :global
                       :group "editing"
                       :help nil
                       :help-order nil
                       :mutates nil
                       :prompts '(:free-string)
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  (register-command-spec :feature/search "replace-string" "replace-string" #'loom/feature/search:replace-string
                       :keys '((:alt #\%))
                       :keymap :global
                       :group "editing"
                       :help nil
                       :help-order nil
                       :mutates t
                       :prompts '(:free-string :free-string)
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  )
