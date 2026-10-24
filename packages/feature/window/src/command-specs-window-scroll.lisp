(in-package #:loom/core/command)

(progn
  (register-command-spec :feature/window "scroll-up-command" "scroll-up-command" #'loom/feature/window:scroll-up-command
                       :keys '((:control #\v))
                       :keymap :global
                       :group "movement"
                       :help nil
                       :help-order nil
                       :mutates nil
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  (register-command-spec :feature/window "scroll-down-command" "scroll-down-command" #'loom/feature/window:scroll-down-command
                       :keys '((:alt #\v))
                       :keymap :global
                       :group "movement"
                       :help nil
                       :help-order nil
                       :mutates nil
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  )
