(in-package #:loom/feature/clipboard)

(register-command-spec :feature/clipboard
                       "clipboard-yank"
                       "clipboard-yank"
                       (function clipboard-yank)
                       :keys
                       nil
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
