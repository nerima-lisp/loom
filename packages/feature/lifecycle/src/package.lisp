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
                #:editor-state-minibuffer)
  (:import-from #:loom/core/minibuffer
                #:minibuffer-activate
                #:minibuffer-message)
  (:import-from #:loom/feature/buffers
                #:quit-buffer-list)
  (:export #:loom-quit
           #:loom-quit-abort
           #:save-buffers-kill-terminal
           #:kill-loom-abort
           #:suspend-frame))
