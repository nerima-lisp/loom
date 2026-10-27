(in-package #:loom/core/command)

(progn
  (register-command-spec :core/buffer "delete-char" "delete-char" #'loom:delete-char
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
  (register-command-spec :core/buffer "delete-backward-char" "delete-backward-char" #'loom:delete-backward-char
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
  (register-command-spec :core/buffer "newline" "newline" #'loom:newline-command
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
  (register-command-spec :core/buffer "open-line" "open-line" #'loom:open-line
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

  (progn
  (register-command-spec :core/buffer "upcase-word" "upcase-word" #'upcase-word
                       :keys '((:alt #\u))
                       :keymap :global
                       :group "editing"
                       :help nil
                       :help-order nil
                       :mutates t
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  (register-command-spec :core/buffer "downcase-word" "downcase-word" #'downcase-word
                       :keys '((:alt #\l))
                       :keymap :global
                       :group "editing"
                       :help nil
                       :help-order nil
                       :mutates t
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  (register-command-spec :core/buffer "capitalize-word" "capitalize-word" #'capitalize-word
                       :keys '((:alt #\c))
                       :keymap :global
                       :group "editing"
                       :help nil
                       :help-order nil
                       :mutates t
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:all)))
  (progn
  (register-command-spec :core/buffer "fill-paragraph" "fill-paragraph" #'fill-paragraph
                       :keys '((:alt #\q))
                       :keymap :global
                       :group "editing"
                       :help nil
                       :help-order nil
                       :mutates t
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  (register-command-spec :core/buffer "delete-indentation" "delete-indentation" #'delete-indentation
                       :keys '((:alt #\^))
                       :keymap :global
                       :group "editing"
                       :help nil
                       :help-order nil
                       :mutates t
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:all)))
