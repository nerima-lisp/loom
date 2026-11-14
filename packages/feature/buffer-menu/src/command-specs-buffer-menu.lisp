(in-package #:loom/core/command)

;;; None of these commands edits a file buffer's text; x saves and kills
;;; through FR-404 and KILL-BUFFER's confirmation, like
;;; SAVE-BUFFERS-KILL-TERMINAL, so all are :MUTATES NIL. x declares the
;;; free-string prompt it can open, KILL-BUFFER's s/d/c question.
(register-command-spec :feature/buffer-menu "list-buffers" "list-buffers"
  #'loom/feature/buffer-menu:list-buffers
  :keys '(((:control #\x) (:control #\b))) :keymap :global
  :group "windows and workspaces" :help "C-x C-b List buffers" :help-order 42
  :mutates nil :prompts '() :needs-region nil :external '() :modes '(:all))
(register-command-spec :feature/buffer-menu "buffer-menu-next-line" "buffer-menu-next-line"
  #'loom/feature/buffer-menu:buffer-menu-next-line
  :keys '((#\n)) :keymap :buffer-menu-local
  :group "buffer menu" :help nil :help-order nil
  :mutates nil :prompts '() :needs-region nil :external '() :modes '(:buffer-menu))
(register-command-spec :feature/buffer-menu "buffer-menu-previous-line" "buffer-menu-previous-line"
  #'loom/feature/buffer-menu:buffer-menu-previous-line
  :keys '((#\p)) :keymap :buffer-menu-local
  :group "buffer menu" :help nil :help-order nil
  :mutates nil :prompts '() :needs-region nil :external '() :modes '(:buffer-menu))
(register-command-spec :feature/buffer-menu "buffer-menu-this-window" "buffer-menu-this-window"
  #'loom/feature/buffer-menu:buffer-menu-this-window
  :keys '((:enter)) :keymap :buffer-menu-local
  :group "buffer menu" :help nil :help-order nil
  :mutates nil :prompts '() :needs-region nil :external '() :modes '(:buffer-menu))
(register-command-spec :feature/buffer-menu "buffer-menu-other-window" "buffer-menu-other-window"
  #'loom/feature/buffer-menu:buffer-menu-other-window
  :keys '((#\o)) :keymap :buffer-menu-local
  :group "buffer menu" :help nil :help-order nil
  :mutates nil :prompts '() :needs-region nil :external '() :modes '(:buffer-menu))
(register-command-spec :feature/buffer-menu "buffer-menu-delete" "buffer-menu-delete"
  #'loom/feature/buffer-menu:buffer-menu-delete
  :keys '((#\d)) :keymap :buffer-menu-local
  :group "buffer menu" :help nil :help-order nil
  :mutates nil :prompts '() :needs-region nil :external '() :modes '(:buffer-menu))
(register-command-spec :feature/buffer-menu "buffer-menu-save" "buffer-menu-save"
  #'loom/feature/buffer-menu:buffer-menu-save
  :keys '((#\s)) :keymap :buffer-menu-local
  :group "buffer menu" :help nil :help-order nil
  :mutates nil :prompts '() :needs-region nil :external '() :modes '(:buffer-menu))
(register-command-spec :feature/buffer-menu "buffer-menu-unmark" "buffer-menu-unmark"
  #'loom/feature/buffer-menu:buffer-menu-unmark
  :keys '((#\u)) :keymap :buffer-menu-local
  :group "buffer menu" :help nil :help-order nil
  :mutates nil :prompts '() :needs-region nil :external '() :modes '(:buffer-menu))
(register-command-spec :feature/buffer-menu "buffer-menu-execute" "buffer-menu-execute"
  #'loom/feature/buffer-menu:buffer-menu-execute
  :keys '((#\x)) :keymap :buffer-menu-local
  :group "buffer menu" :help nil :help-order nil
  :mutates nil :prompts '(:free-string) :needs-region nil :external '()
  :modes '(:buffer-menu))
(register-command-spec :feature/buffer-menu "buffer-menu-revert" "buffer-menu-revert"
  #'loom/feature/buffer-menu:buffer-menu-revert
  :keys '((#\g)) :keymap :buffer-menu-local
  :group "buffer menu" :help nil :help-order nil
  :mutates nil :prompts '() :needs-region nil :external '() :modes '(:buffer-menu))
(register-command-spec :feature/buffer-menu "buffer-menu-quit" "buffer-menu-quit"
  #'loom/feature/buffer-menu:buffer-menu-quit
  :keys '((#\q)) :keymap :buffer-menu-local
  :group "buffer menu" :help nil :help-order nil
  :mutates nil :prompts '() :needs-region nil :external '() :modes '(:buffer-menu))
(loom/feature/mode:register-major-mode
 :buffer-menu
 :name "Buffer Menu"
 :keybindings
 (list
  (cons #\n #'loom/feature/buffer-menu:buffer-menu-next-line)
  (cons #\p #'loom/feature/buffer-menu:buffer-menu-previous-line)
  (cons :enter #'loom/feature/buffer-menu:buffer-menu-this-window)
  (cons #\o #'loom/feature/buffer-menu:buffer-menu-other-window)
  (cons #\d #'loom/feature/buffer-menu:buffer-menu-delete)
  (cons #\s #'loom/feature/buffer-menu:buffer-menu-save)
  (cons #\u #'loom/feature/buffer-menu:buffer-menu-unmark)
  (cons #\x #'loom/feature/buffer-menu:buffer-menu-execute)
  (cons #\g #'loom/feature/buffer-menu:buffer-menu-revert)
  (cons #\q #'loom/feature/buffer-menu:buffer-menu-quit)))
