(defpackage #:loom/feature/workspace
  (:use #:cl #:loom #:loom/application #:loom/feature/window)
  (:export
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
   #:new-workspace
   #:next-workspace
   #:previous-workspace
   #:switch-workspace
   #:kill-workspace))
