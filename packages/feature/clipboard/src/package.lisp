(defpackage #:loom/feature/clipboard
            (:use #:cl)
            (:import-from #:loom/core/command
                          #:invoke-command
                          #:register-command-spec)
            (:import-from #:loom/core/editor-session
                          #:*editor-state*
                          #:editor-state-minibuffer
                          #:register-session-hook)
            (:import-from #:loom/core/minibuffer #:minibuffer-message)
            (:import-from #:loom/feature/kill-ring #:yank)
            (:import-from #:loom/feature/shell
                          #:run-shell-command
                          #:shell-command-result-success-p
                          #:shell-command-result-output
                          #:shell-command-result-error-output)
            (:export #:clipboard-copy-text
                     #:clipboard-read-text
                     #:clipboard-yank))
