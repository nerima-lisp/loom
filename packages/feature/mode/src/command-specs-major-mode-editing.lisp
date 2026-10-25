(in-package #:loom/core/command)

(progn
  (register-command-spec :feature/mode
                         "indent-for-tab-command"
                         "indent-for-tab-command"
                         #'loom/feature/mode:indent-for-tab-command
                         :keys '(:tab)
                         :keymap :global
                         :group "editing"
                         :help nil
                         :help-order nil
                         :mutates t
                         :prompts 'nil
                         :needs-region nil
                         :external 'nil
                         :modes '(:all))
  (register-command-spec :feature/mode
                         "comment-line"
                         "comment-line"
                         #'loom/feature/mode:comment-line
                         :keys '((:alt #\;))
                         :keymap :global
                         :group "editing"
                         :help nil
                         :help-order nil
                         :mutates t
                         :prompts 'nil
                         :needs-region nil
                         :external 'nil
                         :modes '(:common-lisp :python :rust :shell :emacs-lisp :nix :typescript :typescript-react :markdown :org)))

(register-internal-command
 :feature/mode "mode/comment-dwim" (function loom/feature/mode:comment-dwim)
 :mutates t :prompts nil :needs-region nil :external nil :modes (list :all))
