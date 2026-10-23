(defpackage #:loom-user
  (:use #:cl #:loom #:loom/feature/lsp #:loom/feature/mode
        #:loom/feature/user-init)
  (:shadowing-import-from #:loom/feature/mode #:buffer-truncate-lines-p))
