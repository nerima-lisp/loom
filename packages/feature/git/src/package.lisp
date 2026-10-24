(defpackage #:loom/feature/git
            (:documentation
             "Git status, diff, staging, and unstaging commands.")
            (:use #:cl #:vcs-kit)
            (:export #:run-git-status
                     #:git-status
                     #:run-git-diff
                     #:git-diff
                     #:git-diff-staged
                     #:run-git-stage
                     #:git-stage-file
                     #:run-git-unstage
                     #:git-unstage-file
                     #:*git-command-timeout-seconds*)
            (:import-from #:loom/feature/buffers
                          #:registered-buffers
                          #:register-buffer)
            (:import-from #:loom/core/buffer
                          #:buffer-delete-region
                          #:buffer-insert-string
                          #:buffer-mark-saved
                          #:buffer-name
                          #:buffer-offset-position
                          #:buffer-path
                          #:buffer-position-column
                          #:buffer-position-line
                          #:buffer-set-read-only
                          #:buffer-text
                          #:make-buffer)
            (:import-from #:loom/feature/project
                          #:project-directory-path
                          #:project-find-root)
            (:import-from #:loom/feature/window #:window-set-buffer)
            (:import-from #:loom/core/minibuffer
                          #:minibuffer-message
                          #:with-prompts)
            (:import-from #:loom/core/editor-session
                          #:*editor-session*
                          #:*editor-state*
                          #:editor-state-minibuffer
                          #:editor-state-window-tree))
