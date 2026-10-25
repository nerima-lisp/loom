(in-package #:loom/core/command)

(progn
  (register-command-spec :core/buffer "delete-char" "delete-char" #'loom::delete-char
                       :keys '((:control #\d) :delete)
                       :keymap :global
                       :group "editing"
                       :help nil
                       :help-order nil
                       :mutates t
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  (register-command-spec :core/buffer "delete-backward-char" "delete-backward-char" #'loom::delete-backward-char
                       :keys '(:backspace)
                       :keymap :global
                       :group "editing"
                       :help nil
                       :help-order nil
                       :mutates t
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  (register-command-spec :core/buffer "newline" "newline" #'loom::newline-command
                       :keys '(:enter)
                       :keymap :global
                       :group "editing"
                       :help nil
                       :help-order nil
                       :mutates t
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  (register-command-spec :core/buffer "open-line" "open-line" #'loom::open-line
                       :keys '((:control #\o))
                       :keymap :global
                       :group "editing"
                       :help nil
                       :help-order nil
                       :mutates t
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  )
