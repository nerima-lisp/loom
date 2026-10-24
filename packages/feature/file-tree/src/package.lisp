(defpackage #:loom/feature/file-tree
            (:use #:cl)
            (:export #:make-file-tree
                     #:file-tree-visible-p
                     #:file-tree-toggle
                     #:file-tree-entries
                     #:file-tree-selected-path
                     #:file-tree-entry-kind
                     #:file-tree-move-selection
                     #:file-tree-toggle-expand
                     #:file-tree-child-lister
                     #:file-tree-install-child-lister
                     #:file-tree-prefetch-paths
                     #:file-tree-create-file
                     #:file-tree-create-directory
                     #:file-tree-rename
                     #:file-tree-delete
                     #:loom-fs-list-directory
                     #:make-loom-concurrent-runtime
                     #:loom-concurrent-runtime-directory-entries
                     #:loom-concurrent-runtime-directory-error
                     #:loom-concurrent-runtime-prime-directory
                     #:loom-concurrent-runtime-invalidate-directory
                     #:loom-concurrent-runtime-invalidate-path
                     #:loom-concurrent-runtime-prefetch
                     #:loom-concurrent-runtime-drain
                     #:loom-concurrent-runtime-shutdown
                     #:toggle-file-tree
                     #:file-tree-select-next
                     #:file-tree-select-previous
                     #:file-tree-open-selected
                     #:file-tree-create-file-command
                     #:file-tree-create-directory-command
                     #:file-tree-rename-command
                     #:file-tree-delete-command
                     #:find-file
                     #:visit-file
                     #:recent-file
                     #:save-buffer
                     #:write-file
                     #:register-recent-file-recorder)
            (:import-from #:loom/feature/buffers #:register-buffer)
            (:import-from #:loom/core/editor-session #:*editor-session*)
            (:import-from #:loom/core/buffer
                          #:buffer-load
                          #:buffer-mark
                          #:buffer-mark-saved
                          #:buffer-name
                          #:buffer-path
                          #:buffer-point-column
                          #:buffer-point-line
                          #:buffer-read-only-error
                          #:buffer-read-only-p
                          #:buffer-save
                          #:buffer-set-major-mode
                          #:buffer-set-mark
                          #:buffer-set-point
                          #:buffer-set-read-only
                          #:buffer-text
                          #:make-buffer)
            (:import-from #:loom/core/editor-session
                          #:*editor-state*
                          #:editor-state-concurrent-runtime
                          #:editor-state-file-tree
                          #:editor-state-minibuffer
                          #:editor-state-recent-files
                          #:editor-state-window-tree
                          #:run-before-save-hooks
                          #:run-after-save-hooks)
            (:import-from #:loom/core/minibuffer
                          #:minibuffer-message
                          #:with-prompts))
