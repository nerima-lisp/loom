(defpackage #:loom/core/window-tree
            (:use #:cl)
            (:export #:window-tree
                     #:window-tree-p
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
                     #:window-tree-resize))
