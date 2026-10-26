(in-package #:loom/core/command)

(progn
  (register-command-spec :feature/lifecycle
                         "save-buffers-kill-terminal"
                         "save-buffers-kill-terminal"
                         (function loom/feature/lifecycle:save-buffers-kill-terminal)
                         :keys (quote (((:control #\x) (:control #\c))))
                         :keymap :global
                         :group "ui and lifecycle"
                         :help "C-x C-c Exit"
                         :help-order 37
                         :mutates nil
                         :prompts (quote (:free-string))
                         :needs-region nil
                         :external (quote ())
                         :modes (quote (:all)))
  (register-command-spec :feature/lifecycle
                         "kill-loom-abort"
                         "kill-loom-abort"
                         (function loom/feature/lifecycle:kill-loom-abort)
                         :keys nil
                         :keymap :global
                         :group "ui and lifecycle"
                         :help "M-x kill-loom-abort Abort"
                         :help-order 38
                         :mutates nil
                         :prompts (quote (:free-string))
                         :needs-region nil
                         :external (quote ())
                         :modes (quote (:all)))
  (register-command-spec :feature/lifecycle
                         "suspend-frame"
                         "suspend-frame"
                         (function loom/feature/lifecycle:suspend-frame)
                         :keys (quote (((:control #\z))))
                         :keymap :global
                         :group "ui and lifecycle"
                         :help "C-z Suspend frame"
                         :help-order 39
                         :mutates nil
                         :prompts nil
                         :needs-region nil
                         :external (quote ())
                         :modes (quote (:all))))
