;;;; src/package.lisp
;;;;
;;;; The single public package for loom. Every symbol the protocol declares
;;;; -- across the buffer, renderer, keymap, minibuffer, window, and
;;;; file-tree modules, now laid out package-by-feature under
;;;; domain/, infrastructure/, application/, and presentation/ (mirroring
;;;; nshell/src's layering) -- is exported here, plus the shared editor-state
;;;; struct/special-variable and the MAIN entry point. Feature agents filling
;;;; in real :method bodies against these already-exported names in their
;;;; respective layer files do not need to change this file's export list;
;;;; it is the fixed contract, only the file layout moved.
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
   #:buffer-undo
   #:buffer-record-undo-boundary
   #:buffer-load
   #:buffer-save

   ;; Renderer protocol (src/infrastructure/terminal-renderer.lisp)
   #:make-loom-renderer
   #:loom-renderer-cl-tty-renderer
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
   #:window-buffer
   #:window-set-buffer
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
   #:file-tree-move-selection
   #:file-tree-toggle-expand
   #:file-tree-create-file
   #:file-tree-create-directory
   #:file-tree-rename
   #:file-tree-delete
   #:loom-fs-list-directory

   ;; Editor state (src/application/editor-state.lisp): the special variable
   ;; and struct that every command in src/application/commands.lisp operates on.
   #:*editor-state*
   #:editor-state
   #:make-editor-state
   #:editor-state-window-tree
   #:editor-state-minibuffer
   #:editor-state-keymap
   #:editor-state-file-tree
   #:editor-state-renderer
   #:editor-state-kill-ring

   ;; Entry point (src/main.lisp)
   #:main))
