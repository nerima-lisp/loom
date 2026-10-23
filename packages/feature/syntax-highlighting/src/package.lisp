(defpackage #:loom/feature/syntax-highlighting
  (:use #:cl #:loom #:loom/feature/mode)
  (:shadowing-import-from #:loom/feature/mode #:buffer-truncate-lines-p)
  (:export
   #:syntax-token
   #:syntax-token-p
   #:syntax-token-kind
   #:syntax-token-text
   #:syntax-highlight-line
   #:syntax-highlight-line-for-mode
   #:syntax-draw-highlighted-line
   #:syntax-draw-buffer))
