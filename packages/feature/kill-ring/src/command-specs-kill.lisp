(in-package #:loom/core/command)

(progn
  (register-command-spec :feature/kill-ring "kill-line" "kill-line" #'loom:kill-line
                       :keys '((:control #\k))
                       :keymap :global
                       :group "editing"
                       :help "C-k Cut"
                       :help-order 31
                       :mutates t
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  (register-command-spec :feature/kill-ring "kill-word" "kill-word" #'loom:kill-word
                       :keys '((:alt #\d))
                       :keymap :global
                       :group "editing"
                       :help nil
                       :help-order nil
                       :mutates t
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  (register-command-spec :feature/kill-ring "backward-kill-word" "backward-kill-word" #'loom:backward-kill-word
                       :keys '((:alt :backspace))
                       :keymap :global
                       :group "editing"
                       :help nil
                       :help-order nil
                       :mutates t
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  (register-command-spec :feature/kill-ring "kill-region" "kill-region" #'loom:kill-region
                       :keys '((:control #\w))
                       :keymap :global
                       :group "editing"
                       :help nil
                       :help-order nil
                       :mutates t
                       :prompts 'nil
                       :needs-region t
                       :external 'nil
                       :modes '(:all))
  (register-command-spec :feature/kill-ring "kill-ring-save" "kill-ring-save" #'loom:kill-ring-save
                       :keys '((:alt #\w))
                       :keymap :global
                       :group "editing"
                       :help "M-w Copy"
                       :help-order 32
                       :mutates nil
                       :prompts 'nil
                       :needs-region t
                       :external 'nil
                       :modes '(:all))
  )
