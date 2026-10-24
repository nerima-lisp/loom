(defpackage #:loom/core/command
  (:use #:cl)
  (:import-from #:loom/core/buffer
                #:buffer-insert-string
                #:buffer-record-undo-boundary)
  (:import-from #:loom/core/editor-session
                #:*editor-state*
                #:editor-state-clear-last-yank
                #:editor-state-last-command-kill-p
                #:editor-state-last-command-self-insert-p
                #:editor-state-minibuffer
                #:editor-state-prefix-argument
                #:editor-state-window-tree)
  (:import-from #:loom/core/minibuffer
                #:minibuffer-message)
  (:export
   #:keymap
   #:keymap-p
   #:make-keymap
   #:keymap-define-key
   #:keymap-lookup
   #:keymap-state
   #:keymap-state-p
   #:make-keymap-state
   #:keymap-state-sequence
   #:keymap-state-use-keymap
   #:keymap-state-dispatch
   #:key-event->descriptor
   #:prefix-argument
   #:make-prefix-argument
   #:prefix-argument-active-p
   #:prefix-argument-explicit-p
   #:prefix-argument-value
   #:prefix-argument-universal
   #:prefix-argument-digit
   #:prefix-argument-negative
   #:prefix-argument-consume
   #:prefix-argument-reset
   #:prefix-argument-action
   #:prefix-argument-for-editor
   #:prefix-argument-value-for-editor
   #:apply-prefix-argument-action
   #:consume-prefix-argument-for-editor
   #:*current-prefix-argument*
   #:repeat-command
   #:record-undo-boundary-for-command
   #:self-insert-command
   #:invoke-command
   #:command-spec
   #:command-spec-group
   #:define-command-spec-groups
   #:build-command-specs
   #:define-command-specs
   #:define-command-spec-catalog
   #:*command-specs*
   #:command-completion-candidates
   #:find-extended-command-spec
   #:record-command-trace
   #:command-catalog-json
   #:help-summary-message
   #:defkeys-single-chord-p
   #:defkeys-chord
   #:defkeys-key-sequence
   #:install-default-keybindings #:register-buffer-keymap-provider #:keymap-for-buffer))
