(defpackage #:loom/feature/mode
  (:use #:cl)
  (:import-from #:loom/core/buffer
                #:buffer-active-region-span
                #:buffer-deactivate-mark
                #:buffer-delete-region
                #:buffer-insert-string
                #:buffer-line
                #:buffer-line-count
                #:buffer-major-mode
                #:buffer-mark
                #:buffer-mark-active-p
                #:buffer-offset-position
                #:buffer-position-column
                #:buffer-position-line
                #:buffer-read-only-p
                #:buffer-span-end
                #:buffer-span-start
                #:buffer-point-column
                #:buffer-point-line
                #:buffer-set-major-mode
                #:buffer-set-mark
                #:buffer-set-point
                #:buffer-set-truncate-lines
                #:buffer-truncate-lines)
  (:import-from #:loom/core/command
                #:defkeys-key-sequence
                #:keymap-define-key
                #:keymap-lookup
                #:make-keymap
                #:register-buffer-keymap-provider)
  (:import-from #:loom/core/editor-session
                #:*editor-state*
                #:editor-state-completion
                #:editor-state-minibuffer
                #:editor-state-window-tree
                #:register-session-hook
                #:register-buffer-truncate-policy)
  (:import-from #:loom/core/minibuffer
                #:minibuffer-active-p
                #:minibuffer-message
                #:with-prompts)
  (:import-from #:loom/core/window-tree
                #:window-buffer
                #:window-tree-selected-window)
  (:shadow #:buffer-truncate-lines-p)
  (:export
   #:major-mode-known-p
   #:major-mode-from-name
   #:major-mode-name
   #:major-mode-comment-prefix
   #:major-mode-indentation-width
   #:major-mode-tab-width
   #:major-mode-language-id
   #:major-mode-keywords
   #:major-mode-truncate-lines-p
   #:buffer-truncate-lines-p
   #:major-mode-names
   #:major-mode-for-path
   #:major-mode-parent
   #:major-mode-keybindings
   #:major-mode-definition
   #:register-major-mode
   #:unregister-major-mode
   #:major-mode-keymap
   #:current-major-mode
   #:set-major-mode
   #:indent-for-tab-command
   #:indent-region
   #:newline-and-indent
   #:register-major-mode-indentation-rule
   #:major-mode-indentation-column
   #:comment-line
   #:toggle-truncate-lines
   #:major-mode-comment-start
   #:major-mode-comment-end
   #:major-mode-skip-closing-delimiter-p
   #:comment-dwim))
