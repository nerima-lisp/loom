(defpackage #:loom/feature/mouse
  (:use #:cl)
  (:import-from #:cl-tty-kit
                #:mouse-event
                #:mouse-event-action
                #:mouse-event-button
                #:mouse-event-x
                #:mouse-event-y)
  (:import-from #:loom/core/buffer
                #:buffer-deactivate-mark
                #:buffer-mark
                #:buffer-mark-active-p
                #:buffer-narrow-start-offset
                #:buffer-offset-position
                #:buffer-point-column
                #:buffer-point-line
                #:buffer-position-column
                #:buffer-position-line
                #:buffer-set-mark
                #:buffer-set-point
                #:buffer-visible-line
                #:buffer-visible-line-count)
  (:import-from #:loom/core/command
                #:invoke-command)
  (:import-from #:loom/core/editor-session
                #:*editor-state*
                #:editor-state-file-tree
                #:editor-state-session
                #:editor-state-window-tree
                #:hit-test-coordinate
                #:hit-test-result-buffer
                #:hit-test-result-kind
                #:hit-test-result-position
                #:hit-test-result-target
                #:hit-test-result-window
                #:make-hit-test-result
                #:register-hit-test-provider
                #:register-session-hook)
  (:import-from #:loom/core/window-tree
                #:window-buffer
                #:window-scroll-column
                #:window-tree-height
                #:window-tree-select-index
                #:window-tree-windows)
  (:import-from #:loom/feature/file-tree
                #:file-tree-entries
                #:file-tree-move-selection
                #:file-tree-selected-path
                #:file-tree-visible-p)
  (:export))
