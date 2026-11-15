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

(register-command-spec :feature/lifecycle "recover-file" "recover-file"
  #'loom/feature/lifecycle:recover-file
  :keys nil :keymap :global
  :group "ui and lifecycle" :help "M-x recover-file Recover unsaved work" :help-order 40
  :mutates t :prompts '(:char) :needs-region nil :external '() :modes '(:all))
(register-command-spec :feature/lifecycle "list-recoverable-files" "list-recoverable-files"
  #'loom/feature/lifecycle:list-recoverable-files
  :keys nil :keymap :global
  :group "ui and lifecycle" :help "M-x list-recoverable-files List unsaved work"
  :help-order 41
  :mutates nil :prompts '() :needs-region nil :external '() :modes '(:all))
;;; RET opens a file and hands over to recover-file, whose spec declares the
;;; char prompt and the edit, so this command itself neither prompts nor edits.
(register-command-spec :feature/lifecycle "recover-list-visit" "recover-list-visit"
  #'loom/feature/lifecycle:recover-list-visit
  :keys '((:enter)) :keymap :recover-list-local
  :group "ui and lifecycle" :help nil :help-order nil
  :mutates nil :prompts '() :needs-region nil :external '() :modes '(:recover-list))
(loom/feature/mode:register-major-mode
 :recover-list
 :name "Recover List"
 :keybindings
 (list (cons :enter #'loom/feature/lifecycle:recover-list-visit)))
