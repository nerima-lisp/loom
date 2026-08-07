;;;; src/package.lisp
;;;;
;;;; The single public package for loom. Every symbol the protocol declares
;;;; -- across the buffer, renderer, keymap, minibuffer, window, and
;;;; file-tree modules, laid out package-by-feature under domain/,
;;;; infrastructure/, application/, and presentation/ (mirroring nshell/src's
;;;; layering) -- is exported here, plus the shared editor-state
;;;; struct/special-variable and the MAIN entry point, grouped below by the
;;;; source file that defines each group. Application-layer commands
;;;; (src/application/commands-*.lisp) are deliberately NOT exported -- see
;;;; commands-internal.lisp's header comment for why.
(defpackage #:loom
  (:use #:cl)
  (:export
   ;; Buffer protocol (src/domain/buffer.lisp)
   #:make-buffer
   #:buffer-name
   #:buffer-path
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

   ;; Renderer protocol (src/infrastructure/terminal-renderer.lisp)
   #:make-loom-renderer
   #:loom-renderer-width
   #:loom-renderer-height
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
   #:minibuffer-handle-key
   #:minibuffer-message

   ;; Window protocol (src/domain/window.lisp)
   #:make-window-tree
   #:window-tree-windows
   #:window-tree-selected-window
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

   ;; File-tree protocol (src/domain/file-tree.lisp;
   ;; src/infrastructure/filesystem.lisp for the disk-touching operations)
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

   ;; Concurrent file-tree runtime (src/infrastructure/concurrent-runtime.lisp)
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

   ;; Entry point (src/main.lisp)
   #:main))
