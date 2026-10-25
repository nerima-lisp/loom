(defpackage #:loom/feature/mode
  (:use #:cl)
  (:import-from #:loom/core/buffer
                #:buffer-delete-region
                #:buffer-insert-string
                #:buffer-line
                #:buffer-major-mode
                #:buffer-point-column
                #:buffer-point-line
                #:buffer-set-major-mode
                #:buffer-set-point
                #:buffer-set-truncate-lines
                #:buffer-truncate-lines)
  (:import-from #:loom/core/command
                #:defkeys-key-sequence
                #:keymap-define-key
                #:make-keymap
                #:register-buffer-keymap-provider)
  (:import-from #:loom/core/editor-session
                #:*editor-state*
                #:editor-state-minibuffer
                #:editor-state-window-tree
                #:register-buffer-truncate-policy)
  (:import-from #:loom/core/minibuffer
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
   #:comment-line
   #:toggle-truncate-lines #:major-mode-comment-start #:major-mode-comment-end #:major-mode-skip-closing-delimiter-p))
