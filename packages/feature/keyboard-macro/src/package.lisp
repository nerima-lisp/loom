(defpackage #:loom/feature/keyboard-macro
  (:use #:cl)
  (:import-from #:loom/core/command
                #:*current-prefix-argument*
                #:apply-prefix-argument-action
                #:consume-prefix-argument-for-editor
                #:find-extended-command-spec
                #:invoke-command
                #:invoke-key-command
                #:keymap-for-buffer
                #:keymap-state-dispatch
                #:keymap-state-sequence
                #:keymap-state-use-keymap
                #:make-keymap-state
                #:prefix-argument-action
                #:prefix-argument-for-editor
                #:prefix-argument-reset
                #:prefix-argument-value-for-editor
                #:record-undo-boundary-for-command
                #:*current-command-route*
                #:self-insert-command)
  (:import-from #:loom/core/editor-session
                #:*editor-state*
                #:editor-state-keyboard-macro
                #:editor-state-keymap
                #:editor-state-minibuffer
                #:editor-state-session
                #:editor-state-window-tree
                #:register-slice-state)
  (:import-from #:loom/core/minibuffer
                #:minibuffer-message)
  (:import-from #:loom/core/window-tree
                #:window-buffer
                #:window-tree-selected-window)
  (:export
   #:keyboard-macro-event
   #:keyboard-macro-event-p
   #:make-keyboard-macro-event
   #:keyboard-macro-event-kind
   #:keyboard-macro-event-value
   #:keyboard-macro
   #:keyboard-macro-p
   #:make-keyboard-macro
   #:keyboard-macro-events
   #:keyboard-macro-recording-p
   #:keyboard-macro-replaying-p
   #:keyboard-macro-start-recording
   #:keyboard-macro-stop-recording
   #:keyboard-macro-drop
   #:keyboard-macro-record-event
   #:keyboard-macro-remove-last-event
   #:keyboard-macro-begin-replay
   #:keyboard-macro-end-replay
   #:start-kbd-macro
   #:end-kbd-macro
   #:call-last-kbd-macro))
