(in-package #:loom/core/command)
(register-command-spec :feature/keyboard-macro "start-kbd-macro" "start-kbd-macro" #'loom/feature/keyboard-macro:start-kbd-macro
  :keys '(((:control #\x) #\()) :keymap :global :group "macros and evaluation" :help "C-x ( Start macro" :help-order 27
  :mutates nil :prompts '() :needs-region nil :external '() :modes '(:all))
(register-command-spec :feature/keyboard-macro "end-kbd-macro" "end-kbd-macro" #'loom/feature/keyboard-macro:end-kbd-macro
  :keys '(((:control #\x) #\))) :keymap :global :group "macros and evaluation" :help "C-x ) End macro" :help-order 28
  :mutates nil :prompts '() :needs-region nil :external '() :modes '(:all))
(register-command-spec :feature/keyboard-macro "call-last-kbd-macro" "call-last-kbd-macro" #'loom/feature/keyboard-macro:call-last-kbd-macro
  :keys '(((:control #\x) #\e)) :keymap :global :group "macros and evaluation" :help "C-x e Replay macro" :help-order 29
  :mutates t :prompts '() :needs-region nil :external '() :modes '(:all))
