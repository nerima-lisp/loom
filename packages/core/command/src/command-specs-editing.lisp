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
  (progn
  (register-command-spec :core/buffer "back-to-indentation" "back-to-indentation" #'back-to-indentation
                         :keys '((:alt #\m)) :keymap :global :group "editing"
                         :help "M-m indent" :help-order 44 :mutates nil
                         :prompts nil :needs-region nil :external nil :modes '(:all))
  (register-command-spec :core/buffer "delete-horizontal-space" "delete-horizontal-space" #'delete-horizontal-space
                         :keys '((:alt #\\)) :keymap :global :group "editing"
                         :help "M-\\ delete space" :help-order 45 :mutates t
                         :prompts nil :needs-region nil :external nil :modes '(:all))
  (register-command-spec :core/buffer "just-one-space" "just-one-space" #'just-one-space
                         :keys '((:alt #\Space)) :keymap :global :group "editing"
                         :help "M-SPC space" :help-order 46 :mutates t
                         :prompts nil :needs-region nil :external nil :modes '(:all))
  (register-command-spec :core/buffer "transpose-words" "transpose-words" #'transpose-words
                         :keys '((:alt #\t)) :keymap :global :group "editing"
                         :help "M-t words" :help-order 47 :mutates t
                         :prompts nil :needs-region nil :external nil :modes '(:all))
  (register-command-spec :core/buffer "count-words-region" "count-words-region" #'count-words-region
                         :keys '((:alt #\=)) :keymap :global :group "editing"
                         :help "M-= count" :help-order 48 :mutates nil
                         :prompts nil :needs-region nil :external nil :modes '(:all)))
