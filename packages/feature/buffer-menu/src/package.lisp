(defpackage #:loom/feature/buffer-menu
  (:use #:cl)
  (:import-from #:loom/core/buffer
                #:buffer-delete-region
                #:buffer-insert-string
                #:buffer-line
                #:buffer-line-count
                #:buffer-major-mode
                #:buffer-mark-saved
                #:buffer-modified-p
                #:buffer-name
                #:buffer-narrow-end-offset
                #:buffer-narrow-start-offset
                #:buffer-path
                #:buffer-point-line
                #:buffer-read-only-p
                #:buffer-set-major-mode
                #:buffer-set-point
                #:buffer-set-read-only)
  (:import-from #:loom/core/command
                #:invoke-key-command
                #:key-event->descriptor
                #:keymap-for-buffer
                #:keymap-lookup
                #:prefix-argument-active-p)
  (:import-from #:loom/core/editor-session
                #:*editor-session*
                #:*editor-state*
                #:editor-state-clear-last-yank
                #:editor-state-keymap
                #:editor-state-last-command-kill-p
                #:editor-state-minibuffer
                #:editor-state-prefix-argument
                #:editor-state-window-tree
                #:register-session-hook)
  (:import-from #:loom/core/minibuffer
                #:minibuffer-active-p
                #:minibuffer-message)
  (:import-from #:loom/core/window-tree
                #:window-buffer
                #:window-delete
                #:window-set-buffer
                #:window-split
                #:window-tree-select-index
                #:window-tree-selected-window
                #:window-tree-windows)
  (:import-from #:loom/feature/buffers
                #:ensure-result-buffer
                #:kill-buffer-with-confirmation
                #:registered-buffers
                #:run-buffer-switch-guard)
  (:import-from #:loom/feature/files
                #:confirm-save-buffer)
  (:import-from #:loom/feature/mode
                #:major-mode-keymap
                #:major-mode-name)
  (:export #:list-buffers
           #:buffer-menu-next-line
           #:buffer-menu-previous-line
           #:buffer-menu-this-window
           #:buffer-menu-other-window
           #:buffer-menu-delete
           #:buffer-menu-save
           #:buffer-menu-unmark
           #:buffer-menu-execute
           #:buffer-menu-revert
           #:buffer-menu-quit))
