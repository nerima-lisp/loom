(defpackage #:loom/feature/window
            (:use #:cl #:loom #:loom/application)
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
                     #:kill-buffer))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (let ((source (find-package "LOOM/CORE/WINDOW-TREE"))
        (target (find-package "LOOM/FEATURE/WINDOW")))
    (dolist
        (name
         (quote
          ("MAKE-WINDOW-LEAF" "WINDOW-LEAF-WIDTH"
                              "WINDOW-LEAF-HEIGHT"
                              "MAKE-WINDOW-SPLIT-NODE"
                              "WINDOW-SPLIT-NODE-CHILDREN"
                              "%WINDOW-DELETE-NODE")))
      (import (intern name source) target))))
