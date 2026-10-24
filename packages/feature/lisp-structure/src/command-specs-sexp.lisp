(in-package #:loom/core/command)

(progn
  (register-command-spec :feature/lisp-structure "forward-sexp" "forward-sexp" #'loom::forward-sexp
                       :keys '((:control :alt #\f))
                       :keymap :global
                       :group "movement"
                       :help nil
                       :help-order nil
                       :mutates nil
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  (register-command-spec :feature/lisp-structure "backward-sexp" "backward-sexp" #'loom::backward-sexp
                       :keys '((:control :alt #\b))
                       :keymap :global
                       :group "movement"
                       :help nil
                       :help-order nil
                       :mutates nil
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  (register-command-spec :feature/lisp-structure "backward-up-list" "backward-up-list" #'loom::backward-up-list
                       :keys '((:control :alt #\u))
                       :keymap :global
                       :group "movement"
                       :help nil
                       :help-order nil
                       :mutates nil
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  (register-command-spec :feature/lisp-structure "down-list" "down-list" #'loom::down-list
                       :keys '((:control :alt #\d))
                       :keymap :global
                       :group "movement"
                       :help nil
                       :help-order nil
                       :mutates nil
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  (register-command-spec :feature/lisp-structure "kill-sexp" "kill-sexp" #'loom::kill-sexp
                       :keys '((:control :alt #\k))
                       :keymap :global
                       :group "movement"
                       :help nil
                       :help-order nil
                       :mutates t
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  )
