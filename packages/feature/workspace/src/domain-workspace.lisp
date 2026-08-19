;;;; packages/feature/workspace/src/domain-workspace.lisp
;;;;
;;;; Public workspace domain API for construction and lifecycle operations.
(in-package #:loom/feature/workspace)

(defun make-workspace-manager-from-workspaces (workspaces
                                                &key (current-index 0))
  "Build a manager from WORKSPACES, validating names and CURRENT-INDEX."
  (%validate-workspaces workspaces current-index)
  (%make-workspace-manager :workspaces (copy-list workspaces)
                           :current-index current-index))

(defun make-workspace-manager (initial-window-tree &key (name "main"))
  "Build a manager with one workspace named NAME over INITIAL-WINDOW-TREE."
  (make-workspace-manager-from-workspaces
   (list (make-workspace :name name :window-tree initial-window-tree))))

(defun %ensure-workspace-name-available (manager workspace-name)
  "Signal when WORKSPACE-NAME is blank or already present in MANAGER."
  (unless (%workspace-name-valid-p workspace-name)
    (error "Workspace name cannot be empty: ~S" workspace-name))
  (when (%workspace-name-conflict-p
         (workspace-manager-workspaces manager)
         workspace-name)
    (error "Workspace already exists: ~A" workspace-name)))

(defun %workspace-manager-append (manager workspace)
  "Append WORKSPACE to MANAGER and return WORKSPACE."
  (setf (workspace-manager-workspaces manager)
        (append (workspace-manager-workspaces manager)
                (list workspace)))
  workspace)

(defun %workspace-manager-without-index (manager index)
  "Return MANAGER workspaces without the entry at INDEX."
  (loop for workspace in (workspace-manager-workspaces manager)
        for position from 0
        unless (= position index)
          collect workspace))

(defun %workspace-manager-current-index-after-delete (manager index)
  "Return the next current index after deleting INDEX from MANAGER."
  (let ((current (workspace-manager-current-index manager)))
    (cond
      ((> current index) (1- current))
      ((= current index)
       (min index
            (1- (length (workspace-manager-workspaces manager)))))
      (t current))))

(defun workspace-manager-create (manager window-tree &key name)
  "Append a new workspace over WINDOW-TREE and return it.

When NAME is omitted, a stable unused WORKSPACE-N name is generated.  The
new workspace is not made active until an explicit switch operation."
  (let ((workspace-name (or name (%workspace-generated-name manager))))
    (%ensure-workspace-name-available manager workspace-name)
    (%workspace-manager-append
     manager
     (make-workspace :name workspace-name :window-tree window-tree))))

(defun workspace-manager-delete (manager &optional
                                           (index
                                             (workspace-manager-current-index
                                              manager)))
  "Delete the workspace at INDEX and return the new active workspace.

The final workspace cannot be deleted.  If the active index was removed, the
nearest remaining workspace becomes active."
  (when (= (length (workspace-manager-workspaces manager)) 1)
    (error "Cannot delete the final workspace"))
  (unless (%workspace-index-valid-p
           (workspace-manager-workspaces manager)
           index)
    (error "Workspace index is out of range: ~S" index))
  (setf (workspace-manager-workspaces manager)
        (%workspace-manager-without-index manager index))
  (setf (workspace-manager-current-index manager)
        (%workspace-manager-current-index-after-delete manager index))
  (workspace-manager-current manager))
