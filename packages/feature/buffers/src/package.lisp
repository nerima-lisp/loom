(defpackage #:loom/feature/buffers
  (:use #:cl)
  (:import-from #:loom/core/buffer
                #:buffer-modified-p
                #:buffer-name
                #:buffer-path
                #:make-buffer)
  (:import-from #:loom/core/editor-session
                #:*editor-session*
                #:*editor-state*
                #:editor-session-slice
                #:editor-state-minibuffer
                #:editor-state-window-tree
                #:register-slice-state
                #:run-session-hooks)
  (:import-from #:loom/core/minibuffer
                #:minibuffer-activate
                #:minibuffer-message
                #:with-prompts)
  (:import-from #:loom/core/window-tree
                #:window-buffer
                #:window-set-buffer
                #:window-tree-selected-window
                #:window-tree-windows)
  (:export #:register-buffer
           #:unregister-buffer
           #:registered-buffers
           #:find-buffer-by-name
           #:find-buffer-by-path
           #:ensure-result-buffer
           #:register-buffer-switch-guard
           #:register-buffer-save-handler
           #:run-buffer-switch-guard
           #:switch-to-buffer
           #:kill-buffer
           #:kill-buffer-with-confirmation
           #:quit-buffer-list))
