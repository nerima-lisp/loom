(defpackage #:loom/feature/terminal
            (:documentation
             "Terminal session management and terminal screen state.")
            (:use #:cl)
            (:export #:terminal-screen
                     #:terminal-screen-p
                     #:terminal-screen-width
                     #:terminal-screen-height
                     #:terminal-screen-cursor-row
                     #:terminal-screen-cursor-column
                     #:make-terminal-screen
                     #:terminal-screen-feed
                     #:terminal-screen-text
                     #:terminal-screen-resize
                     #:terminal-session
                     #:terminal-session-p
                     #:terminal-session-name
                     #:terminal-session-program
                     #:terminal-session-args
                     #:terminal-session-directory
                     #:terminal-session-buffer
                     #:terminal-session-pty
                     #:terminal-session-raw-output
                     #:terminal-session-alive-p
                     #:terminal-session-exit-code
                     #:terminal-session-screen
                     #:terminal-session-output
                     #:terminal-session-feed-output
                     #:terminal-session-for-buffer
                     #:start-terminal-session
                     #:terminal-session-poll
                     #:terminal-session-send
                     #:terminal-session-resize
                     #:stop-terminal-session
                     #:poll-terminal-sessions
                     #:resize-terminal-sessions
                     #:terminal-input-event-p
                     #:terminal-handle-key-event
                     #:terminal
                     #:terminal-stop
                     #:terminal-event-loop-background-work-p
                     #:terminal-event-loop-poll-sessions
                     #:terminal-event-loop-resize-sessions)
            (:import-from #:loom/feature/buffers
                          #:registered-buffers
                          #:register-buffer)
            (:import-from #:loom/core/editor-session
                          #:*editor-session*
                          #:editor-state-session
                          #:*editor-state*
                          #:editor-state-window-tree
                          #:editor-state-terminal-sessions
                          #:editor-state-minibuffer)
            (:import-from #:loom/core/buffer
                          #:buffer-delete-region
                          #:buffer-insert-string
                          #:buffer-mark-saved
                          #:buffer-name
                          #:buffer-offset-position
                          #:buffer-path
                          #:buffer-position-column
                          #:buffer-position-line
                          #:buffer-set-point
                          #:buffer-set-read-only
                          #:buffer-text
                          #:make-buffer)
            (:import-from #:loom/core/minibuffer #:minibuffer-message)
            (:import-from #:loom/core/window-tree
                          #:window-buffer
                          #:window-set-buffer
                          #:window-tree-selected-window))
