;;;; packages/feature/window/src/package.lisp
;;;;
;;;; The window feature owns window-tree domain operations and their commands.
(defpackage #:loom/feature/window
  (:use #:cl #:loom #:loom/application)
  (:export
   ;; Domain API
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
   #:window-x
   #:window-y
   #:window-width
   #:window-height
   #:window-tree-resize
   ;; Application API
   #:split-window-below
   #:split-window-right
   #:other-window
   #:delete-window
   #:delete-other-windows
   #:switch-to-buffer
   #:kill-buffer))
