(define-package-with-exports #:loom (#:cl #:loom/core/buffer #:loom/core/command #:loom/core/minibuffer #:loom/core/editor-session) #.+loom-exports+
  (:import-from #:loom/feature/bookmark
                #:editor-bookmark-p
                #:make-editor-bookmark
                #:editor-bookmark-name
                #:editor-bookmark-buffer
                #:editor-bookmark-path
                #:editor-bookmark-buffer-name
                #:editor-bookmark-line
                #:editor-bookmark-column))
