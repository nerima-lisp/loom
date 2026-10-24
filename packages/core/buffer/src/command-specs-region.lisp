(in-package #:loom/core/command)

(progn
  (register-command-spec :core/buffer "set-mark-command" "set-mark-command" #'loom::set-mark-command
                       :keys '((:control #\Space))
                       :keymap :global
                       :group "editing"
                       :help nil
                       :help-order nil
                       :mutates nil
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  (register-command-spec :core/buffer "exchange-point-and-mark" "exchange-point-and-mark" #'loom::exchange-point-and-mark
                       :keys '(((:control #\x) (:control #\x)))
                       :keymap :global
                       :group "editing"
                       :help nil
                       :help-order nil
                       :mutates nil
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  (register-command-spec :core/buffer "mark-whole-buffer" "mark-whole-buffer" #'loom::mark-whole-buffer
                       :keys '(((:control #\x) #\h))
                       :keymap :global
                       :group "editing"
                       :help nil
                       :help-order nil
                       :mutates nil
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  (register-command-spec :core/buffer "narrow-to-region" "narrow-to-region" #'loom::narrow-to-region
                       :keys '(((:control #\x) #\n #\n))
                       :keymap :global
                       :group "editing"
                       :help nil
                       :help-order nil
                       :mutates nil
                       :prompts 'nil
                       :needs-region t
                       :external 'nil
                       :modes '(:all))
  (register-command-spec :core/buffer "widen" "widen" #'loom::widen
                       :keys '(((:control #\x) #\n #\w))
                       :keymap :global
                       :group "editing"
                       :help nil
                       :help-order nil
                       :mutates nil
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  (register-command-spec :core/buffer "toggle-read-only" "toggle-read-only" #'loom::toggle-read-only
                       :keys '(((:control #\x) (:control #\q)))
                       :keymap :global
                       :group "editing"
                       :help nil
                       :help-order nil
                       :mutates nil
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  (register-command-spec :core/buffer "undo" "undo" #'loom::undo-command
                       :keys '(((:control #\x) (:control #\u)))
                       :keymap :global
                       :group "editing"
                       :help "C-x C-u Undo"
                       :help-order 34
                       :mutates t
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  (register-command-spec :core/buffer "redo" "redo" #'loom::redo-command
                       :keys '(((:control #\x) (:control #\y)))
                       :keymap :global
                       :group "editing"
                       :help "C-x C-y Redo"
                       :help-order 35
                       :mutates t
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  )
