(defpackage #:loom/feature/files
  (:use #:cl)
  (:import-from #:loom/feature/buffers
                #:find-buffer-by-name
                #:find-buffer-by-path
                #:register-buffer)
  (:import-from #:loom/core/buffer
                #:buffer-delete-region
                #:buffer-insert-string
                #:buffer-load
                #:buffer-mark
                #:buffer-mark-saved
                #:buffer-modified-p
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
                #:buffer-widen
                #:make-buffer)
  (:import-from #:loom/core/editor-session
                #:*editor-session*
                #:*editor-state*
                #:*editor-recent-file-limit*
                #:editor-state-minibuffer
                #:editor-state-recent-files
                #:editor-state-window-tree
                #:register-session-hook
                #:run-session-hooks)
  (:import-from #:loom/core/minibuffer
                #:minibuffer-activate
                #:minibuffer-message
                #:with-prompts)
  (:export #:editor-path-string
           #:remember-recent-file
           #:find-file
           #:visit-file
           #:recent-file
           #:save-buffer
           #:write-file
           #:revert-buffer
           #:file-format-indicator
           #:register-recent-file-recorder
           #:*loom-filesystem*
           #:*loom-real-filesystem*
           #:%native-path-operation-p
           #:%native-path-exists-p
           #:%native-namestring
           #:%native-directory-prefixes
           #:%native-directory-p))
