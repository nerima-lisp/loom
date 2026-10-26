(in-package #:loom/core/command)
(progn
  (register-command-spec
   :feature/help "help" "help" #'loom/feature/help:help-command
   :keys '(:f1)
   :keymap :global
   :group "help"
   :help "Show the help summary in *Help*."
   :help-order 1
   :mutates nil
   :prompts '()
   :needs-region nil
   :external '()
   :modes '(:all))
  (register-command-spec
   :feature/help "describe-key" "describe-key" #'loom/feature/help:describe-key
   :keys '((( :control #\h) #\k))
   :keymap :global
   :group "help"
   :help "Describe a key sequence (C-h k)."
   :help-order 2
   :mutates nil
   :prompts '(:free-string)
   :needs-region nil
   :external '()
   :modes '(:all))
  (register-command-spec
   :feature/help "describe-command" "describe-command" #'loom/feature/help:describe-command
   :keys '((( :control #\h) #\x))
   :keymap :global
   :group "help"
   :help "Describe a command (C-h x)."
   :help-order 3
   :mutates nil
   :prompts '(:completion)
   :needs-region nil
   :external '()
   :modes '(:all))
  (register-command-spec
   :feature/help "describe-bindings" "describe-bindings" #'loom/feature/help:describe-bindings
   :keys '((( :control #\h) #\b))
   :keymap :global
   :group "help"
   :help "Show bindings for the global and current mode keymaps (C-h b)."
   :help-order 4
   :mutates nil
   :prompts '()
   :needs-region nil
   :external '()
   :modes '(:all))
  (register-command-spec
   :feature/help "describe-mode" "describe-mode" #'loom/feature/help:describe-mode
   :keys '((( :control #\h) #\m))
   :keymap :global
   :group "help"
   :help "Describe the current major mode (C-h m)."
   :help-order 5
   :mutates nil
   :prompts '()
   :needs-region nil
   :external '()
   :modes '(:all)))
