(in-package #:loom/core/command)
(register-command-spec :feature/evaluation "eval-expression" "eval-expression" #'loom/feature/evaluation:eval-expression
  :keys '((:alt #\:)) :keymap :global :group "macros and evaluation" :help "M-: Eval" :help-order 2
  :mutates t :prompts '(:free-string) :needs-region nil :external '() :modes '(:all))
(register-command-spec :feature/evaluation "eval-buffer" "eval-buffer" #'loom/feature/evaluation:eval-buffer
  :keys '(((:control #\x) (:control #\e))) :keymap :global :group "macros and evaluation" :help "C-x C-e Eval buffer" :help-order 3
  :mutates t :prompts '() :needs-region nil :external '() :modes '(:all))
