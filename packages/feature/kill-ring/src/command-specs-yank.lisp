(in-package #:loom/core/command)

(progn
  (register-command-spec :feature/kill-ring "yank" "yank" #'loom::yank
                       :keys '((:control #\y))
                       :keymap :global
                       :group "editing"
                       :help "C-y Paste"
                       :help-order 33
                       :mutates t
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  (register-command-spec :feature/kill-ring "yank-pop" "yank-pop" #'loom::yank-pop
                       :keys '((:alt #\y))
                       :keymap :global
                       :group "editing"
                       :help "M-y Yank previous"
                       :help-order 36
                       :mutates t
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  )
