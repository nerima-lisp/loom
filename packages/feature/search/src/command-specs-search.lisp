(in-package #:loom/core/command)

(progn
  (register-command-spec
   :feature/search "search-forward" "search-forward"
   #'loom/feature/search:search-forward
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
  (register-command-spec
   :feature/search "search-backward" "search-backward"
   #'loom/feature/search:search-backward
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
  (register-command-spec
   :feature/search "replace-string" "replace-string"
   #'loom/feature/search:replace-string
   :keys 'nil
   :keymap :global
   :group "editing"
   :help nil
   :help-order nil
   :mutates t
   :prompts '(:free-string :free-string)
   :needs-region nil
   :external 'nil
   :modes '(:all))
  (register-command-spec
   :feature/search "search-replace-regexp" "replace-regexp"
   #'loom/feature/search::replace-regexp
   :keys 'nil
   :keymap :global
   :group "editing"
   :help nil
   :help-order nil
   :mutates t
   :prompts '(:free-string :free-string)
   :needs-region nil
   :external 'nil
   :modes '(:all))
  (register-command-spec
   :feature/search "search-query-replace" "query-replace"
   #'loom/feature/search::query-replace
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
  (register-command-spec
   :feature/search "search-query-replace-regexp" "query-replace-regexp"
   #'loom/feature/search::query-replace-regexp
   :keys '((:control :alt #\%))
   :keymap :global
   :group "editing"
   :help nil
   :help-order nil
   :mutates t
   :prompts '(:free-string :free-string)
   :needs-region nil
   :external 'nil
   :modes '(:all))
  (register-command-spec
   :feature/search "search-next-error" "next-error"
   #'loom/feature/search:next-error
   :keys '(((:alt #\g) #\n))
   :keymap :global
   :group "editing"
   :help nil
   :help-order nil
   :mutates nil
   :prompts 'nil
   :needs-region nil
   :external 'nil
   :modes '(:all))
  (register-command-spec
   :feature/search "search-previous-error" "previous-error"
   #'loom/feature/search:previous-error
   :keys '(((:alt #\g) #\p))
   :keymap :global
   :group "editing"
   :help nil
   :help-order nil
   :mutates nil
   :prompts 'nil
   :needs-region nil
   :external 'nil
   :modes '(:all))
  (register-command-spec
   :feature/search "search-result-visit" "search-result-visit"
   #'loom/feature/search:search-result-visit
   :keys 'nil
   :keymap :global
   :group "editing"
   :help nil
   :help-order nil
   :mutates nil
   :prompts 'nil
   :needs-region nil
   :external 'nil
   :modes '(:all)))
