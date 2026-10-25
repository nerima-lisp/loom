(defpackage #:loom/feature/bookmark
  (:use #:cl)
  (:import-from #:loom/core/buffer
                #:buffer-load
                #:buffer-name
                #:buffer-path
                #:buffer-point-line
                #:buffer-point-column
                #:buffer-set-point)
  (:import-from #:loom/core/editor-session
                #:*editor-session*
                #:*editor-state*
                #:editor-state-bookmarks
                #:editor-state-minibuffer
                #:editor-state-window-tree)
  (:import-from #:loom/core/minibuffer
                #:minibuffer-message
                #:with-prompts)
  (:import-from #:loom/core/window-tree
                #:window-buffer
                #:window-set-buffer
                #:window-tree-selected-window)
  (:import-from #:loom/feature/buffers
                #:register-buffer
                #:registered-buffers)
  (:import-from #:loom/feature/files
                #:editor-path-string
                #:remember-recent-file)
  (:export #:editor-bookmark
           #:editor-bookmark-p
           #:make-editor-bookmark
           #:editor-bookmark-name
           #:editor-bookmark-buffer
           #:editor-bookmark-path
           #:editor-bookmark-buffer-name
           #:editor-bookmark-line
           #:editor-bookmark-column))
