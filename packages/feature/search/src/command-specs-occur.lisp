(in-package #:loom/core/command)
(register-command-spec
 :feature/search "search-occur" "occur"
 #'loom/feature/search:occur
 :keys nil
 :keymap :global
 :group "editing"
 :help "M-x occur List matching lines"
 :help-order 33
 :mutates nil
 :prompts '(:free-string)
 :needs-region nil
 :external '()
 :modes '(:all))
