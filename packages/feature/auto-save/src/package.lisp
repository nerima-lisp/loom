(defpackage #:loom/feature/auto-save
            (:documentation
             "Automatic saving of modified buffers to recovery files.")
            (:use #:cl)
            (:import-from #:loom/core/buffer
                          #:buffer-modified-p
                          #:buffer-name
                          #:buffer-p
                          #:buffer-path
                          #:buffer-read-only-p
                          #:buffer-text)
            (:import-from #:loom/core/editor-session
                          #:*editor-state*
                          #:editor-state-auto-save-buffers
                          #:editor-state-auto-save-last-run-at
                          #:editor-state-auto-save-mode-p
                          #:editor-state-session
                          #:editor-state-minibuffer
                          #:editor-state-window-tree
                          #:register-session-hook)
            (:import-from #:loom/core/minibuffer #:minibuffer-message)
            (:import-from #:loom/core/window-tree
                          #:window-buffer
                          #:window-tree-selected-window)
            (:export #:*auto-save-interval*
                     #:auto-save-path
                     #:auto-save-eligible-p
                     #:write-auto-save-file
                     #:delete-auto-save-file
                     #:auto-save-buffer-to-file
                     #:auto-save-enabled-p
                     #:auto-save-mode
                     #:toggle-auto-save
                     #:auto-save-current-buffer
                     #:maybe-auto-save)
            (:import-from #:loom/feature/buffers #:registered-buffers))
