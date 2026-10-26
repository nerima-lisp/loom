(in-package #:loom/core/command)

(progn
  (register-command-spec :feature/lisp-structure "forward-slurp-sexp" "forward-slurp-sexp" #'loom::forward-slurp-sexp
                       :keys nil
                       :keymap :lisp-mode-local
                       :group "movement"
                       :help nil
                       :help-order nil
                       :mutates t
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:common-lisp :emacs-lisp))
  (register-command-spec :feature/lisp-structure "forward-barf-sexp" "forward-barf-sexp" #'loom::forward-barf-sexp
                       :keys nil
                       :keymap :lisp-mode-local
                       :group "movement"
                       :help nil
                       :help-order nil
                       :mutates t
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:common-lisp :emacs-lisp))
  (register-command-spec :feature/lisp-structure "backward-slurp-sexp" "backward-slurp-sexp" #'loom::backward-slurp-sexp
                       :keys nil
                       :keymap :lisp-mode-local
                       :group "movement"
                       :help nil
                       :help-order nil
                       :mutates t
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:common-lisp :emacs-lisp))
  (register-command-spec :feature/lisp-structure "backward-barf-sexp" "backward-barf-sexp" #'loom::backward-barf-sexp
                       :keys nil
                       :keymap :lisp-mode-local
                       :group "movement"
                       :help nil
                       :help-order nil
                       :mutates t
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:common-lisp :emacs-lisp))
  (register-command-spec :feature/lisp-structure "wrap-round" "wrap-round" #'loom::wrap-round
                       :keys nil
                       :keymap :lisp-mode-local
                       :group "movement"
                       :help nil
                       :help-order nil
                       :mutates t
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:common-lisp :emacs-lisp))
  (register-command-spec :feature/lisp-structure "splice-sexp" "splice-sexp" #'loom::splice-sexp
                       :keys nil
                       :keymap :lisp-mode-local
                       :group "movement"
                       :help nil
                       :help-order nil
                       :mutates t
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:common-lisp :emacs-lisp))
  (register-command-spec :feature/lisp-structure "raise-sexp" "raise-sexp" #'loom::raise-sexp
                       :keys nil
                       :keymap :lisp-mode-local
                       :group "movement"
                       :help nil
                       :help-order nil
                       :mutates t
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:common-lisp :emacs-lisp)))
