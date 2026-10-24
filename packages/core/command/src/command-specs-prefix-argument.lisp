(in-package #:loom/core/command)

(progn
  (register-command-spec :core/command "universal-argument" "universal-argument" #'loom::universal-argument
                       :keys '((:control #\u))
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
