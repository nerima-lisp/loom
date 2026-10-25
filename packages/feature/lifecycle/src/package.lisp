(defpackage #:loom/feature/lifecycle
            (:use #:cl)
            (:import-from #:loom/core/buffer
                          #:buffer-modified-p
                          #:buffer-path
                          #:buffer-save)
            (:import-from #:loom/core/editor-session
                          #:*editor-state*
                          #:editor-state-minibuffer)
            (:import-from #:loom/core/minibuffer
                          #:minibuffer-activate
                          #:minibuffer-message)
            (:import-from #:loom/feature/buffers #:quit-buffer-list)
            (:export #:loom-quit #:save-buffers-kill-terminal))
