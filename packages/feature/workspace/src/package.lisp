(defpackage #:loom/feature/workspace
  (:use #:cl)
  (:import-from #:loom/core/editor-session
                #:*editor-state*
                #:editor-state-workspaces
                #:editor-state-window-tree
                #:editor-state-minibuffer
                #:register-slice-state)
  (:import-from #:loom/core/minibuffer
                #:minibuffer-message
                #:with-prompts)
  (:import-from #:loom/core/window-tree
                #:make-window-tree
                #:window-tree-selected-window
                #:window-buffer
                #:window-tree-width
                #:window-tree-height)
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
