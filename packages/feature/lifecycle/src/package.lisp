(defpackage #:loom/feature/lifecycle
  (:use #:cl)
  (:import-from #:loom/core/buffer
                #:buffer-modified-p
                #:buffer-name
                #:buffer-path
                #:buffer-save
                #:buffer-text)
  (:import-from #:loom/core/editor-session
                #:*editor-state*
                #:editor-state-minibuffer
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
  (:import-from #:loom/feature/buffers
                #:quit-buffer-list)
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
           #:loom-quit
           #:loom-quit-abort
           #:save-buffers-kill-terminal
           #:kill-loom-abort
           #:suspend-frame))
