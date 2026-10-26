(in-package #:loom/core/command)
(register-command-spec :feature/evaluation "eval-expression" "eval-expression" #'loom/feature/evaluation:eval-expression
  :keys '((:alt #\:)) :keymap :global :group "macros and evaluation" :help "M-: Eval" :help-order 2
  :mutates t :prompts '(:free-string) :needs-region nil :external '() :modes '(:all))
(register-command-spec :feature/evaluation "eval-last-sexp" "eval-last-sexp" (function loom/feature/evaluation:eval-last-sexp)
  :keys (quote (((:control #\x) (:control #\e)))) :keymap :global :group "macros and evaluation"
  :help "C-x C-e Eval last sexp" :help-order 3
  :mutates t :prompts nil :needs-region nil :external nil :modes (quote (:all)))
(register-command-spec :feature/evaluation "eval-buffer" "eval-buffer" (function loom/feature/evaluation:eval-buffer)
  :keys nil :keymap :global :group "macros and evaluation"
  :mutates t :prompts nil :needs-region nil :external nil :modes (quote (:all)))
