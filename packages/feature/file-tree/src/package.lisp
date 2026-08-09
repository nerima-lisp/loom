;;;; packages/feature/file-tree/src/package.lisp
;;;;
;;;; The file-tree feature owns filesystem navigation and its concurrent
;;;; directory-entry prefetch boundary.
(defpackage #:loom/feature/file-tree
  (:use #:cl #:loom #:loom/application #:loom/feature/window)
  (:export
   ;; Domain API
   #:make-file-tree
   #:file-tree-visible-p
   #:file-tree-toggle
   #:file-tree-entries
   #:file-tree-selected-path
   #:file-tree-entry-kind
   #:file-tree-move-selection
   #:file-tree-toggle-expand
   #:file-tree-create-file
   #:file-tree-create-directory
   #:file-tree-rename
   #:file-tree-delete
   ;; Infrastructure API
   #:loom-fs-list-directory
   #:make-loom-concurrent-runtime
   #:loom-concurrent-runtime-directory-entries
   #:loom-concurrent-runtime-directory-error
   #:loom-concurrent-runtime-prime-directory
   #:loom-concurrent-runtime-invalidate-directory
   #:loom-concurrent-runtime-invalidate-path
   #:loom-concurrent-runtime-prefetch
   #:loom-concurrent-runtime-drain
   #:loom-concurrent-runtime-shutdown
   ;; Application API
   #:toggle-file-tree
   #:file-tree-select-next
   #:file-tree-select-previous
   #:file-tree-open-selected
   #:file-tree-create-file-command
   #:file-tree-create-directory-command
   #:file-tree-rename-command
   #:file-tree-delete-command
   #:find-file
   #:save-buffer
   #:write-file))
