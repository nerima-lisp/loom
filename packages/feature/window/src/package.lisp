(defpackage #:loom/feature/window
            (:use #:cl)
            (:import-from #:loom/core/buffer
                          #:buffer-modified-p
                          #:buffer-name
                          #:buffer-path
                          #:buffer-save
                          #:buffer-visible-line-count
                          #:make-buffer)
            (:import-from #:loom/core/command #:repeat-command)
            (:import-from #:loom/core/editor-session
                          #:*editor-state*
                          #:editor-state-buffers
                          #:editor-state-minibuffer
                          #:editor-state-window-tree)
            (:import-from #:loom/core/minibuffer
                          #:minibuffer-activate
                          #:minibuffer-message)
            (:import-from #:loom/core/window-tree
                          #:make-window-tree
                          #:window-tree-windows
                          #:window-tree-selected-window
                          #:window-tree-layout
                          #:make-window-tree-from-layout
                          #:window-tree-selected-index
                          #:window-tree-select-index
                          #:window-tree-width
                          #:window-tree-height
                          #:window-split
                          #:window-select-next
                          #:window-delete
                          #:window-delete-other-windows
                          #:window-buffer
                          #:window-set-buffer
                          #:window-scroll-line
                          #:window-scroll-column
                          #:window-scroll-sub-row
                          #:window-x
                          #:window-y
                          #:window-width
                          #:window-height
                          #:window-tree-resize)
            (:export #:make-window-tree
                     #:window-tree-windows
                     #:window-tree-selected-window
                     #:window-tree-layout
                     #:make-window-tree-from-layout
                     #:window-tree-selected-index
                     #:window-tree-select-index
                     #:window-tree-width
                     #:window-tree-height
                     #:window-split
                     #:window-select-next
                     #:window-delete
                     #:window-delete-other-windows
                     #:window-buffer
                     #:window-set-buffer
                     #:window-scroll-line
                     #:window-scroll-column
                     #:window-scroll-sub-row
                     #:window-x
                     #:window-y
                     #:window-width
                     #:window-height
                     #:window-tree-resize
                     #:split-window-below
                     #:split-window-right
                     #:other-window
                     #:delete-window
                     #:delete-other-windows
                     #:switch-to-buffer
                     #:kill-buffer
                     #:scroll-up-command
                     #:scroll-down-command))
