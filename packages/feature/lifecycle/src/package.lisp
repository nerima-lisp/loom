(defpackage #:loom/feature/lifecycle
  (:use #:cl)
  (:import-from #:loom/core/buffer
                #:buffer-delete-region
                #:buffer-insert-string
                #:buffer-mark-saved
                #:buffer-modified-p
                #:buffer-name
                #:buffer-narrowed-p
                #:buffer-path
                #:buffer-point-line
                #:buffer-read-only-error
                #:buffer-read-only-p
                #:buffer-record-undo-boundary
                #:buffer-save
                #:buffer-set-major-mode
                #:buffer-set-point
                #:buffer-set-read-only
                #:buffer-text
                #:make-buffer)
  (:import-from #:loom/core/editor-session
                #:*editor-state*
                #:editor-state-minibuffer
                #:editor-state-session
                #:editor-state-window-tree
                #:literal-file-path
                #:native-path-basename
                #:native-path-namestring
                #:register-session-hook)
  (:import-from #:loom/core/minibuffer
                #:minibuffer-activate
                #:minibuffer-log-message
                #:minibuffer-message)
  (:import-from #:loom/feature/auto-save
                #:auto-save-path)
  (:import-from #:loom/core/window-tree
                #:window-buffer
                #:window-set-buffer
                #:window-split
                #:window-tree-select-index
                #:window-tree-selected-window
                #:window-tree-windows)
  (:import-from #:loom/feature/buffers
                #:ensure-result-buffer
                #:find-buffer-by-name
                #:quit-buffer-list
                #:register-buffer
                #:registered-buffers)
  (:import-from #:loom/feature/files
                #:find-file-path)
  (:export #:*loom-state-directory*
           #:read-recovery-meta
           #:recovery-entries
           #:recovery-entry
           #:recovery-entry-p
           #:recovery-entry-body
           #:recovery-entry-meta
           #:recovery-entry-path
           #:recovery-entry-buffer-name
           #:recovery-entry-reason
           #:recovery-entry-time
           #:recovery-entry-modification-time
           #:file-path-hash
           #:recovery-entries-with-hashes
           #:recovery-body-count
           #:file-lock-name
           #:buffer-file-truename
           #:read-lock-owner
           #:lock-buffer-file
           #:unlock-buffer-file
           #:relock-moved-buffer-file
           #:release-all-file-locks
           #:flush-lifecycle-messages
           #:recovery-candidate
           #:recovery-candidate-p
           #:recovery-candidate-kind
           #:recovery-candidate-pathname
           #:recovery-candidate-entry
           #:recovery-candidate-text
           #:recovery-candidate-modification-time
           #:recovery-candidate-age
           #:find-recovery-candidate
           #:recovery-entries-for-buffer
           #:format-recovery-age
           #:recovery-candidate-notice
           #:other-loom-notice
           #:delete-stale-auto-save-temporaries
           #:delete-recovery-entries-for-buffer
           #:file-open-notice-shown-p
           #:recover-file
           #:list-recoverable-files
           #:recover-list-visit
           #:loom-quit
           #:loom-quit-abort
           #:save-buffers-kill-terminal
           #:kill-loom-abort
           #:suspend-frame))
