(defpackage #:loom/feature/session
  (:use #:cl #:loom/core/window-tree)
  (:import-from #:loom/core/buffer
                #:make-buffer
                #:buffer-name
                #:buffer-path
                #:buffer-text
                #:buffer-point-line
                #:buffer-point-column
                #:buffer-mark
                #:buffer-set-point
                #:buffer-set-mark
                #:buffer-modified-p
                #:buffer-mark-modified)
  (:import-from #:loom/core/editor-session
                #:*editor-session*
                #:*editor-state*
                #:editor-state-session
                #:editor-state-window-tree
                #:editor-state-workspaces
                #:editor-state-minibuffer
                #:editor-state-recent-files
                #:editor-state-bookmarks)
  (:import-from #:loom/core/minibuffer
                #:minibuffer-message
                #:minibuffer-history-entries
                #:minibuffer-set-history-entries
                #:with-prompts)
  (:import-from #:loom/feature/bookmark
                #:make-editor-bookmark
                #:editor-bookmark-name
                #:editor-bookmark-buffer
                #:editor-bookmark-path
                #:editor-bookmark-buffer-name
                #:editor-bookmark-line
                #:editor-bookmark-column)
  (:import-from #:loom/feature/buffers
                #:registered-buffers
                #:register-buffer
                #:unregister-buffer)
  (:export #:session-buffer-snapshot
           #:make-session-buffer-snapshot
           #:session-buffer-snapshot-name
           #:session-buffer-snapshot-path
           #:session-buffer-snapshot-text
           #:session-buffer-snapshot-point-line
           #:session-buffer-snapshot-point-column
           #:session-buffer-snapshot-mark-line
           #:session-buffer-snapshot-mark-column
           #:session-buffer-snapshot-modified-p
           #:session-bookmark-snapshot
           #:make-session-bookmark-snapshot
           #:session-bookmark-snapshot-name
           #:session-bookmark-snapshot-path
           #:session-bookmark-snapshot-buffer-name
           #:session-bookmark-snapshot-line
           #:session-bookmark-snapshot-column
           #:session-workspace-snapshot
           #:make-session-workspace-snapshot
           #:session-workspace-snapshot-name
           #:session-workspace-snapshot-layout
           #:session-workspace-snapshot-selected-window-index
           #:session-snapshot
           #:make-session-snapshot
           #:session-snapshot-buffers
           #:session-snapshot-recent-files
           #:session-snapshot-bookmarks
           #:session-snapshot-command-history
           #:session-snapshot-workspaces
           #:session-snapshot-current-workspace-index
           #:validate-session-snapshot
           #:session-store-read
           #:session-store-write
           #:save-session
           #:load-session))
