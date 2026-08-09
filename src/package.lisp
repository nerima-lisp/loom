;;;; src/package.lisp
;;;;
;;;; The shared kernel package for loom. Buffer, renderer, keymap, minibuffer,
;;;; state, persistence, and extension protocols live here.
;;;; Feature packages under packages/feature/ own their domain and application
;;;; APIs; the composition root qualifies those APIs explicitly.
(defpackage #:loom/application
  (:use #:cl)
  (:export
   ;; Shared application use-case primitives.  These are the concrete
   ;; operations used by feature commands; the package makes the dependency
   ;; explicit without introducing forwarding adapters.
   #:%selected-window
   #:%selected-buffer
   #:%editor-buffers
   #:%register-buffer
   #:%unregister-buffer
   #:%order-region
   #:with-prompts
   ;; Command registry and keybinding normalization used by the composition
   ;; root and the user-init feature.
   #:command-spec
   #:define-command-specs
   #:*command-specs*
   #:command-completion-candidates
   #:find-extended-command
   #:defkeys-single-chord-p
   #:defkeys-chord
   #:defkeys-key-sequence
   #:install-default-keybindings))

(defpackage #:loom
  (:use #:cl #:loom/application)
  (:export
   ;; Buffer protocol (packages/core/editor/src/domain-buffer.lisp)
   #:make-buffer
   #:buffer-p
   #:buffer-name
   #:buffer-path
   #:buffer-major-mode
   #:buffer-set-major-mode
   #:buffer-text
   #:buffer-line-count
   #:buffer-line
   #:buffer-point-line
   #:buffer-point-column
   #:buffer-set-point
   #:buffer-mark
   #:buffer-set-mark
   #:buffer-insert-string
   #:buffer-delete-char
   #:buffer-delete-region
   #:buffer-region-string
   #:buffer-modified-p
   #:buffer-mark-saved
   #:buffer-mark-modified
   #:buffer-offset
   #:buffer-position
   #:buffer-position-line
   #:buffer-position-column
   #:buffer-span
   #:make-buffer-span
   #:buffer-span-start
   #:buffer-span-end
   #:buffer-point-offset
   #:buffer-offset-position
   #:buffer-undo
   #:buffer-record-undo-boundary
   #:buffer-load
   #:buffer-save

   ;; Renderer protocol (src/infrastructure/terminal-renderer.lisp)
   #:make-loom-renderer
   #:loom-renderer-width
   #:loom-renderer-height
   #:loom-renderer-string-width
   #:loom-renderer-truncate-string
   #:loom-renderer-write-string
   #:loom-renderer-draw-horizontal-line
   #:loom-renderer-draw-vertical-line
   #:loom-renderer-clear
   #:loom-renderer-make-cursor
   #:loom-renderer-draw-buffer
   #:loom-renderer-present
   #:loom-renderer-resize

   ;; Keymap protocol (src/domain/keymap.lisp)
   #:make-keymap
   #:keymap-define-key
   #:keymap-lookup
   #:make-keymap-state
   #:keymap-state-sequence
   #:keymap-state-dispatch

   ;; Minibuffer protocol (src/application/minibuffer.lisp)
   #:make-minibuffer
   #:minibuffer-active-p
   #:minibuffer-prompt-string
   #:minibuffer-input-string
   #:minibuffer-activate
   #:minibuffer-complete
   #:minibuffer-handle-key
   #:minibuffer-message

   ;; Editor state (src/application/editor-state.lisp): the special variable
   ;; and struct that every command in src/application/commands-*.lisp operates on.
   #:*editor-state*
   #:editor-state
   #:make-editor-state
   #:editor-state-window-tree
   #:editor-state-minibuffer
   #:editor-state-keymap
   #:editor-state-file-tree
   #:editor-state-concurrent-runtime
   #:editor-state-renderer
   #:editor-state-buffers
   #:editor-state-kill-ring
   #:editor-state-lsp-session
   #:editor-state-registers
   #:editor-state-keyboard-macro
   #:editor-state-prefix-argument
   #:self-insert-command
   #:*current-prefix-argument*
   #:prefix-argument-for-editor
   #:prefix-argument-action
   #:apply-prefix-argument-action
   #:prefix-argument-value-for-editor
   #:consume-prefix-argument-for-editor
   #:record-undo-boundary-for-command

   ;; Numeric prefix-argument domain (packages/core/editor/src/domain-prefix-argument.lisp)
   #:prefix-argument
   #:prefix-argument-p
   #:make-prefix-argument
   #:prefix-argument-magnitude
   #:prefix-argument-active-p
   #:prefix-argument-explicit-p
   #:prefix-argument-negative-p
   #:prefix-argument-value
   #:prefix-argument-universal
   #:prefix-argument-digit
   #:prefix-argument-negative
   #:prefix-argument-consume
   #:prefix-argument-reset

   ;; Entry point and composition root (src/application/startup.lisp,
   ;; src/main.lisp)
   #:main))
