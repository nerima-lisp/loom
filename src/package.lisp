;;;; src/package.lisp
;;;;
;;;; The single public package for loom. Every symbol the protocol declares
;;;; -- across the buffer, renderer, keymap, minibuffer, window, and
;;;; file-tree modules, laid out by DDD role under src/<DDD>/ and by feature
;;;; under packages/ -- is exported here, plus the shared editor-state
;;;; struct/special-variable and the MAIN entry point, grouped below by the
;;;; source file that defines each group. Application-layer commands
;;;; (src/application/commands-*.lisp and
;;;; packages/feature/*/src/application-*.lisp) are deliberately NOT exported -- see
;;;; commands-internal.lisp's header comment for why.
(defpackage #:loom
  (:use #:cl)
  (:export
   ;; Buffer protocol (packages/core/editor/src/domain-buffer.lisp)
   #:make-buffer
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
   #:buffer-span-start
   #:buffer-span-end
   #:buffer-point-offset
   #:buffer-offset-position
   #:buffer-search-forward
   #:buffer-search-backward
   #:buffer-search-spans
   #:buffer-undo
   #:buffer-record-undo-boundary
   #:buffer-load
   #:buffer-save

   ;; Major-mode catalog and path inference (packages/feature/mode/src/domain-major-mode.lisp)
   #:major-mode-known-p
   #:major-mode-from-name
   #:major-mode-name
   #:major-mode-comment-prefix
   #:major-mode-indentation-width
   #:major-mode-language-id
   #:major-mode-keywords
   #:major-mode-names
   #:major-mode-for-path

   ;; Syntax highlighting protocol (packages/feature/syntax-highlighting/src/domain-syntax-highlighting.lisp)
   #:syntax-token
   #:syntax-token-p
   #:syntax-token-kind
   #:syntax-token-text
   #:syntax-highlight-line
   #:syntax-highlight-line-for-mode

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

   ;; Window protocol (packages/feature/window/src/domain-window.lisp)
   #:make-window-tree
   #:window-tree-windows
   #:window-tree-selected-window
   #:window-tree-layout
   #:make-window-tree-from-layout
   #:window-tree-selected-index
   #:window-tree-select-index
   #:window-tree-width
   #:window-tree-height
   #:window-split
   #:window-select-next
   #:window-delete
   #:window-delete-other-windows
   #:window-buffer
   #:window-set-buffer
   #:window-scroll-line
   #:window-x
   #:window-y
   #:window-width
   #:window-height
   #:window-tree-resize

   ;; File-tree protocol (packages/feature/file-tree/src/domain-file-tree.lisp;
   ;; packages/feature/file-tree/src/infrastructure-filesystem.lisp for the disk-touching operations)
   #:make-file-tree
   #:file-tree-visible-p
   #:file-tree-toggle
   #:file-tree-entries
   #:file-tree-selected-path
   #:file-tree-entry-kind
   #:file-tree-move-selection
   #:file-tree-toggle-expand
   #:file-tree-create-file
   #:file-tree-create-directory
   #:file-tree-rename
   #:file-tree-delete
   #:loom-fs-list-directory

   ;; Project domain and filesystem adapter (packages/feature/project/src/*)
   #:project-marker-names
   #:project-ignored-directory-names
   #:project-marker-name-p
   #:project-directory-path
   #:project-parent-directory
   #:project-root-for-path
   #:project-relative-path
   #:project-search-lines
   #:project-find-root
   #:project-list-files
   #:project-search-files

   ;; Concurrent file-tree runtime (packages/feature/file-tree/src/infrastructure-concurrent-runtime.lisp)
   #:make-loom-concurrent-runtime
   #:loom-concurrent-runtime-directory-entries
   #:loom-concurrent-runtime-directory-error
   #:loom-concurrent-runtime-prime-directory
   #:loom-concurrent-runtime-invalidate-directory
   #:loom-concurrent-runtime-invalidate-path
   #:loom-concurrent-runtime-prefetch
   #:loom-concurrent-runtime-drain
   #:loom-concurrent-runtime-shutdown

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

   ;; Register domain (packages/feature/register/src/domain-register.lisp)
   #:register-value
   #:register-value-p
   #:register-value-kind
   #:register-value-value
   #:register-bank
   #:register-bank-p
   #:make-register-bank
   #:register-bank-put-text
   #:register-bank-text
   #:register-bank-put-position
   #:register-bank-position

   ;; Keyboard-macro domain (packages/feature/keyboard-macro/src/domain-keyboard-macro.lisp)
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

   ;; Session snapshot/store protocol (packages/feature/session/src/domain-session.lisp and
   ;; packages/feature/session/src/infrastructure-session-store.lisp)
   #:session-buffer-snapshot
   #:make-session-buffer-snapshot
   #:session-buffer-snapshot-name
   #:session-buffer-snapshot-path
   #:session-buffer-snapshot-text
   #:session-buffer-snapshot-point-line
   #:session-buffer-snapshot-point-column
   #:session-buffer-snapshot-mark-line
   #:session-buffer-snapshot-mark-column
   #:session-buffer-snapshot-modified-p
   #:session-snapshot
   #:make-session-snapshot
   #:session-snapshot-buffers
   #:session-snapshot-layout
   #:session-snapshot-selected-window-index
   #:validate-session-snapshot
   #:session-store-read
   #:session-store-write

   ;; Lisp evaluation result protocol (packages/feature/evaluation/src/domain-evaluation.lisp and
   ;; packages/feature/evaluation/src/infrastructure-lisp-evaluator.lisp)
   #:evaluation-result
   #:make-evaluation-result
   #:evaluation-result-p
   #:evaluation-result-form-count
   #:evaluation-result-value-lines
   #:evaluation-result-output
   #:evaluation-result-error-output
   #:evaluation-result-error-message
   #:evaluation-result-success-p
   #:evaluation-result-text
   #:evaluate-lisp-source

   ;; Language Server Protocol domain/client (packages/feature/lsp/src/domain-lsp.lisp and
   ;; packages/feature/lsp/src/application-lsp-service.lisp).  JSON framing and child-process
   ;; transports remain infrastructure details; these are the stable editor
   ;; session and diagnostic values exposed to commands and extensions.
   #:lsp-position
   #:make-lsp-position
   #:lsp-position-p
   #:lsp-position-line
   #:lsp-position-character
   #:lsp-range
   #:make-lsp-range
   #:lsp-range-p
   #:lsp-range-start
   #:lsp-range-end
   #:lsp-diagnostic
   #:make-lsp-diagnostic
   #:lsp-diagnostic-p
   #:lsp-diagnostic-range
   #:lsp-diagnostic-message
   #:lsp-diagnostic-severity
   #:lsp-diagnostic-source
   #:lsp-diagnostic-code
   #:lsp-diagnostic-severity-name
   #:lsp-document
   #:make-lsp-document
   #:lsp-document-p
   #:lsp-document-uri
   #:lsp-document-language-id
   #:lsp-document-version
   #:lsp-document-text
   #:make-lsp-session
   #:lsp-session-p
   #:lsp-session-start
   #:lsp-session-drain
   #:lsp-session-refresh
   #:lsp-session-sync-buffer
   #:lsp-session-diagnostics
   #:lsp-session-stop
   #:lsp-session-initialized-p
   #:lsp-session-last-error
   #:lsp-path-uri

   ;; User extension API (packages/feature/user-init/src/application-user-configuration.lisp)
   #:define-command
   #:bind-key
   #:load-user-init

   ;; Entry point (src/main.lisp)
   #:main))

(defpackage #:loom-user
  (:use #:cl #:loom))
