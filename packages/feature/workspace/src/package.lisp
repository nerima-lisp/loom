;;;; packages/feature/workspace/src/package.lisp
;;;;
;;;; In-memory workspace (tab) state and its editor commands.
(defpackage #:loom/feature/workspace
  (:use #:cl #:loom #:loom/application #:loom/feature/window)
  (:export
   ;; Domain API
   #:workspace
   #:workspace-p
   #:make-workspace
   #:workspace-name
   #:workspace-window-tree
   #:workspace-manager
   #:workspace-manager-p
   #:workspace-manager-workspaces
   #:workspace-manager-current-index
   #:make-workspace-manager
   #:make-workspace-manager-from-workspaces
   #:workspace-manager-current
   #:workspace-manager-current-name
   #:workspace-manager-create
   #:workspace-manager-switch-index
   #:workspace-manager-switch-name
   #:workspace-manager-next
   #:workspace-manager-previous
   #:workspace-manager-delete
   ;; Application API
   #:new-workspace
   #:next-workspace
   #:previous-workspace
   #:switch-workspace
   #:kill-workspace))
