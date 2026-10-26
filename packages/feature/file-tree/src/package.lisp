(defpackage #:loom/feature/file-tree
            (:use #:cl)
            (:import-from #:loom/core/editor-session #:*editor-state* #:editor-state-concurrent-runtime #:editor-state-file-tree #:editor-state-minibuffer)
            (:import-from #:loom/core/minibuffer
                          #:minibuffer-message
                          #:with-prompts)
            (:import-from #:loom/feature/files
                          #:find-file
                          #:visit-file
                          #:recent-file
                          #:save-buffer
                          #:write-file
                          #:register-recent-file-recorder
                          #:*loom-filesystem*
                          #:*loom-real-filesystem*
                          #:%native-path-operation-p
                          #:%native-path-exists-p
                          #:%native-namestring
                          #:%native-directory-prefixes
                          #:%native-directory-p)
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
            (:export #:enable-file-tree-runtime #:shutdown-file-tree-runtime #:refresh-file-tree-runtime #:file-tree-runtime-background-work-p))
