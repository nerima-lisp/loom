(in-package #:loom/core/command)

(progn
  (register-command-spec :feature/kill-ring
                         "kill-line"
                         "kill-line"
                         (function loom/feature/kill-ring:kill-line)
                         :keys
                         (list (list :control #\k))
                         :keymap
                         :global
                         :group
                         "editing"
                         :help
                         "C-k Cut"
                         :help-order
                         31
                         :mutates
                         t
                         :prompts
                         nil
                         :needs-region
                         nil
                         :external
                         (list "clipboard")
                         :modes
                         (list :all))
  (register-command-spec :feature/kill-ring
                         "kill-word"
                         "kill-word"
                         (function loom/feature/kill-ring:kill-word)
                         :keys
                         (list (list :alt #\d))
                         :keymap
                         :global
                         :group
                         "editing"
                         :help
                         nil
                         :help-order
                         nil
                         :mutates
                         t
                         :prompts
                         nil
                         :needs-region
                         nil
                         :external
                         (list "clipboard")
                         :modes
                         (list :all))
  (register-command-spec :feature/kill-ring
                         "backward-kill-word"
                         "backward-kill-word"
                         (function loom/feature/kill-ring:backward-kill-word)
                         :keys
                         (list (list :alt :backspace))
                         :keymap
                         :global
                         :group
                         "editing"
                         :help
                         nil
                         :help-order
                         nil
                         :mutates
                         t
                         :prompts
                         nil
                         :needs-region
                         nil
                         :external
                         (list "clipboard")
                         :modes
                         (list :all))
  (register-command-spec :feature/kill-ring
                         "kill-region"
                         "kill-region"
                         (function loom/feature/kill-ring:kill-region)
                         :keys
                         (list (list :control #\w))
                         :keymap
                         :global
                         :group
                         "editing"
                         :help
                         nil
                         :help-order
                         nil
                         :mutates
                         t
                         :prompts
                         nil
                         :needs-region
                         t
                         :external
                         (list "clipboard")
                         :modes
                         (list :all))
  (register-command-spec :feature/kill-ring
                         "kill-ring-save"
                         "kill-ring-save"
                         (function loom/feature/kill-ring:kill-ring-save)
                         :keys
                         (list (list :alt #\w))
                         :keymap
                         :global
                         :group
                         "editing"
                         :help
                         nil
                         :help-order
                         nil
                         :mutates
                         nil
                         :prompts
                         nil
                         :needs-region
                         t
                         :external
                         (list "clipboard")
                         :modes
                         (list :all)))
