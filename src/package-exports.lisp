(eval-when (:compile-toplevel :load-toplevel :execute)
  (defmacro define-package-with-exports (name use exports)
    `(defpackage ,name
       (:use ,@use)
       (:export ,@(mapcar #'string exports))))
  (defparameter +loom/application-exports+
    '(define-selected-buffer-command define-selected-tree-window-command
      %selected-window %selected-window-tree %selected-buffer %editor-buffers %register-buffer
      %unregister-buffer %order-region with-prompts
      command-spec command-spec-group define-command-spec-groups
      build-command-specs define-command-specs
      define-command-spec-catalog *command-specs*
      command-completion-candidates find-extended-command
      help-summary-message defkeys-single-chord-p defkeys-chord
      defkeys-key-sequence install-default-keybindings))
  (defparameter +loom-exports+
    '(make-buffer buffer-p buffer-name buffer-path buffer-major-mode
      buffer-set-major-mode buffer-truncate-lines buffer-set-truncate-lines
      buffer-text buffer-narrow-start-offset
      buffer-narrow-end-offset buffer-narrowed-p buffer-visible-text
      buffer-visible-line-count buffer-visible-line buffer-visible-point-line
      buffer-visible-point-column buffer-visible-offset-position
      buffer-narrow-to-region buffer-widen buffer-line-count buffer-line
      buffer-point-line buffer-point-column buffer-set-point buffer-mark
      buffer-set-mark buffer-insert-string buffer-delete-char
      buffer-delete-region buffer-region-string buffer-modified-p
      buffer-read-only-p buffer-set-read-only buffer-read-only-error
      buffer-read-only-error-buffer buffer-mark-saved buffer-mark-modified
      buffer-offset buffer-position buffer-position-line
      buffer-position-column buffer-span make-buffer-span buffer-span-start
      buffer-span-end buffer-point-offset buffer-offset-position buffer-undo
      buffer-redo buffer-record-undo-boundary buffer-load buffer-save
      make-loom-renderer loom-renderer-width loom-renderer-height
      loom-renderer-string-width loom-renderer-truncate-string
      loom-renderer-clip-index loom-renderer-wrap-segments
      loom-renderer-segment-cells loom-renderer-segment-column
      loom-renderer-write-string loom-renderer-draw-horizontal-line
      loom-renderer-draw-vertical-line loom-renderer-clear
      loom-renderer-make-cursor loom-renderer-draw-buffer
      loom-renderer-present loom-renderer-resize
      make-keymap keymap-define-key keymap-lookup make-keymap-state
      keymap-state-sequence keymap-state-dispatch
      make-minibuffer minibuffer-active-p minibuffer-prompt-string
      minibuffer-input-string minibuffer-activate minibuffer-complete
      minibuffer-handle-key minibuffer-set-prompt
      minibuffer-message minibuffer-message-string
      minibuffer-history-entries minibuffer-set-history-entries
      *editor-state* editor-state make-editor-state editor-state-window-tree
      editor-state-workspaces editor-state-minibuffer editor-state-keymap
      editor-state-file-tree editor-state-concurrent-runtime
      editor-state-renderer editor-state-buffers editor-state-recent-files
      editor-state-bookmarks editor-state-kill-ring
      editor-state-last-yank-ranges editor-state-lsp-session
      editor-state-registers editor-state-keyboard-macro
      editor-state-isearch editor-state-completion editor-state-jump-origins
      make-editor-completion editor-completion-buffer editor-completion-line
      editor-completion-column editor-completion-items
      editor-completion-index editor-completion-selected
      editor-completion-move editor-completion-item-label
      editor-completion-item-text
      editor-state-auto-save-mode-p
      editor-state-auto-save-buffers editor-state-auto-save-last-run-at
      editor-state-format-on-save-p editor-state-format-command
      editor-state-before-save-hooks editor-state-after-save-hooks
      editor-state-terminal-sessions editor-state-prefix-argument
      editor-bookmark editor-bookmark-p make-editor-bookmark
      editor-bookmark-name editor-bookmark-buffer editor-bookmark-path
      editor-bookmark-buffer-name editor-bookmark-line editor-bookmark-column
      editor-path-string remember-recent-file add-before-save-hook
      remove-before-save-hook run-before-save-hooks add-after-save-hook
      remove-after-save-hook run-after-save-hooks *editor-recent-file-limit*
      self-insert-command *current-prefix-argument*
      prefix-argument-for-editor prefix-argument-action
      apply-prefix-argument-action prefix-argument-value-for-editor
      consume-prefix-argument-for-editor record-undo-boundary-for-command
      prefix-argument prefix-argument-p make-prefix-argument
      prefix-argument-magnitude prefix-argument-active-p
      prefix-argument-explicit-p prefix-argument-negative-p
      prefix-argument-value prefix-argument-universal prefix-argument-digit
      prefix-argument-negative prefix-argument-consume prefix-argument-reset
      loom-version main)))
