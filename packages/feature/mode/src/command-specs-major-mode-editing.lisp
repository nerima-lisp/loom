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

(%register-command-spec
 :feature/mode
 "mode/comment-dwim"
 nil
 (function loom/feature/mode:comment-dwim)
 :keys nil
 :keymap :global
 :group nil
 :help nil
 :help-order nil
 :mutates t
 :prompts nil
 :needs-region nil
 :external nil
 :modes (list :all)
 :catalog-visible-p nil
 :trace-visible-p t)
(%register-command-spec
 :feature/mode
 "mode/newline-and-indent"
 nil
 (function loom/feature/mode:newline-and-indent)
 :keys nil
 :keymap :global
 :group nil
 :help nil
 :help-order nil
 :mutates t
 :prompts nil
 :needs-region nil
 :external nil
 :modes '(:all)
 :catalog-visible-p nil
 :trace-visible-p t)
