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
                #:native-path-namestring)
  (:import-from #:loom/core/minibuffer
                #:minibuffer-activate
                #:minibuffer-message)
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
           #:loom-quit
           #:loom-quit-abort
           #:save-buffers-kill-terminal
           #:kill-loom-abort
           #:suspend-frame))
