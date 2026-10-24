(defpackage #:loom/feature/syntax-highlighting
            (:use #:cl)
            (:import-from #:loom/feature/mode
                          #:buffer-truncate-lines-p
                          #:major-mode-comment-prefix
                          #:major-mode-from-name
                          #:major-mode-keywords)
            (:export #:syntax-token
                     #:syntax-token-p
                     #:syntax-token-kind
                     #:syntax-token-text
                     #:syntax-highlight-line
                     #:syntax-highlight-line-for-mode
                     #:syntax-draw-highlighted-line
                     #:syntax-draw-buffer
                     #:register-renderer-operation-provider
                     #:call-renderer-operation)
            (:import-from #:loom/core/buffer
                          #:buffer-major-mode
                          #:buffer-visible-line
                          #:buffer-visible-line-count))
