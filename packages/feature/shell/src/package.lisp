(defpackage #:loom/feature/shell
            (:documentation "Shell command execution and result types.")
            (:use #:cl)
            (:export #:shell-command-result
                     #:shell-command-result-p
                     #:make-shell-command-result
                     #:shell-command-result-command
                     #:shell-command-result-directory
                     #:shell-command-result-output
                     #:shell-command-result-error-output
                     #:shell-command-result-exit-code
                     #:shell-command-result-success-p
                     #:shell-command-result-text
                     #:*shell-command-timeout-seconds*
                     #:run-shell-command
                     #:pipe-command)
            (:import-from #:loom/feature/buffers
                          #:registered-buffers
                          #:register-buffer)
            (:import-from #:loom/core/editor-session
                          #:*editor-session*
                          #:*editor-state*
                          #:editor-state-minibuffer
                          #:editor-state-window-tree)
            (:import-from #:loom/core/buffer
                          #:buffer-insert-string
                          #:buffer-line
                          #:buffer-line-count
                          #:buffer-mark-saved
                          #:buffer-name
                          #:buffer-path
                          #:buffer-set-point
                          #:buffer-text
                          #:make-buffer)
            (:import-from #:loom/core/minibuffer
                          #:minibuffer-message
                          #:with-prompts))
