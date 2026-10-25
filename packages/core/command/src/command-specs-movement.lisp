(in-package #:loom/core/command)

(progn
  (register-command-spec :core/buffer "forward-char" "forward-char" #'loom::forward-char
                       :keys '((:control #\f) :right)
                       :keymap :global
                       :group "movement"
                       :help nil
                       :help-order nil
                       :mutates nil
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  (register-command-spec :core/buffer "backward-char" "backward-char" #'loom::backward-char
                       :keys '((:control #\b) :left)
                       :keymap :global
                       :group "movement"
                       :help nil
                       :help-order nil
                       :mutates nil
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  (register-command-spec :core/buffer "next-line" "next-line" #'loom::next-line
                       :keys '((:control #\n) :down)
                       :keymap :global
                       :group "movement"
                       :help nil
                       :help-order nil
                       :mutates nil
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  (register-command-spec :core/buffer "previous-line" "previous-line" #'loom::previous-line
                       :keys '((:control #\p) :up)
                       :keymap :global
                       :group "movement"
                       :help nil
                       :help-order nil
                       :mutates nil
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  (register-command-spec :core/buffer "forward-word" "forward-word" #'loom::forward-word
                       :keys '((:alt #\f))
                       :keymap :global
                       :group "movement"
                       :help nil
                       :help-order nil
                       :mutates nil
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  (register-command-spec :core/buffer "backward-word" "backward-word" #'loom::backward-word
                       :keys '((:alt #\b))
                       :keymap :global
                       :group "movement"
                       :help nil
                       :help-order nil
                       :mutates nil
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  (register-command-spec :core/buffer "move-beginning-of-line" "move-beginning-of-line" #'loom::move-beginning-of-line
                       :keys '((:control #\a) :home)
                       :keymap :global
                       :group "movement"
                       :help nil
                       :help-order nil
                       :mutates nil
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  (register-command-spec :core/buffer "move-end-of-line" "move-end-of-line" #'loom::move-end-of-line
                       :keys '((:control #\e) :end)
                       :keymap :global
                       :group "movement"
                       :help nil
                       :help-order nil
                       :mutates nil
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  (register-command-spec :core/buffer "beginning-of-buffer" "beginning-of-buffer" #'loom::beginning-of-buffer
                       :keys '((:alt #\<))
                       :keymap :global
                       :group "movement"
                       :help nil
                       :help-order nil
                       :mutates nil
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  (register-command-spec :core/buffer "end-of-buffer" "end-of-buffer" #'loom::end-of-buffer
                       :keys '((:alt #\>))
                       :keymap :global
                       :group "movement"
                       :help nil
                       :help-order nil
                       :mutates nil
                       :prompts 'nil
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  (register-command-spec :core/buffer "goto-line" "goto-line" #'loom::goto-line
                       :keys '(((:alt #\g) (:alt #\g)))
                       :keymap :global
                       :group "movement"
                       :help nil
                       :help-order nil
                       :mutates nil
                       :prompts '(:numeric)
                       :needs-region nil
                       :external 'nil
                       :modes '(:all))
  )
