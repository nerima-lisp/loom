;;;; packages/feature/workspace/src/domain-workspace.lisp
;;;;
;;;; Domain layer: the editor's in-memory collection of named window trees.
;;;; Buffers remain session-wide; a workspace owns only a view (WINDOW-TREE),
;;;; which makes switching cheap and keeps the workspace boundary explicit.
(in-package #:loom/feature/workspace)

(defstruct (workspace
            (:constructor make-workspace (&key name window-tree)))
  "One named editor view over a WINDOW-TREE."
  name
  window-tree)

(defstruct (workspace-manager
            (:constructor %make-workspace-manager))
  "Ordered workspaces and the index of the active one."
  workspaces
  current-index)

(defun %workspace-name-valid-p (name)
  (and (stringp name)
       (plusp (length (string-trim '(#\Space #\Tab #\Newline #\Return)
                                   name)))))

(defun %validate-workspace (workspace)
  (unless (and (typep workspace 'workspace)
               (%workspace-name-valid-p (workspace-name workspace)))
    (error "Invalid workspace: ~S" workspace))
  workspace)

(defun %validate-workspaces (workspaces current-index)
  (unless (and (listp workspaces) (plusp (length workspaces)))
    (error "A workspace manager needs one or more workspaces"))
  (dolist (workspace workspaces)
    (%validate-workspace workspace))
  (let ((names (mapcar #'workspace-name workspaces)))
    (unless (= (length names)
               (length (remove-duplicates names :test #'string-equal)))
      (error "Workspace names must be unique: ~S" names)))
  (unless (and (integerp current-index)
               (<= 0 current-index)
               (< current-index (length workspaces)))
    (error "Workspace index is out of range: ~S" current-index))
  workspaces)

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

(defun workspace-manager-current (manager)
  "Return MANAGER's active workspace."
  (nth (workspace-manager-current-index manager)
       (workspace-manager-workspaces manager)))

(defun workspace-manager-current-name (manager)
  "Return MANAGER's active workspace name."
  (workspace-name (workspace-manager-current manager)))

(defun %workspace-generated-name (manager)
  (loop for number from 2
        for candidate = (format nil "workspace-~D" number)
        unless (find candidate (workspace-manager-workspaces manager)
                    :key #'workspace-name :test #'string-equal)
          do (return candidate)))

(defun workspace-manager-create (manager window-tree &key name)
  "Append a new workspace over WINDOW-TREE and return it.

When NAME is omitted, a stable unused WORKSPACE-N name is generated.  The
new workspace is not made active until an explicit switch operation."
  (let ((workspace-name (or name (%workspace-generated-name manager))))
    (unless (%workspace-name-valid-p workspace-name)
      (error "Workspace name cannot be empty: ~S" workspace-name))
    (when (find workspace-name (workspace-manager-workspaces manager)
                :key #'workspace-name :test #'string-equal)
      (error "Workspace already exists: ~A" workspace-name))
    (let ((workspace (make-workspace :name workspace-name
                                     :window-tree window-tree)))
      (setf (workspace-manager-workspaces manager)
            (append (workspace-manager-workspaces manager)
                    (list workspace)))
      workspace)))

(defun workspace-manager-switch-index (manager index)
  "Make the workspace at INDEX active and return it."
  (unless (and (integerp index)
               (<= 0 index)
               (< index (length (workspace-manager-workspaces manager))))
    (error "Workspace index is out of range: ~S" index))
  (setf (workspace-manager-current-index manager) index)
  (workspace-manager-current manager))

(defun workspace-manager-switch-name (manager name)
  "Make the workspace named NAME active and return it, or NIL if absent."
  (let ((index (position name (workspace-manager-workspaces manager)
                        :key #'workspace-name :test #'string-equal)))
    (when index
      (workspace-manager-switch-index manager index))))

(defun workspace-manager-next (manager)
  "Activate the next workspace, wrapping at the end."
  (workspace-manager-switch-index
   manager
   (mod (1+ (workspace-manager-current-index manager))
        (length (workspace-manager-workspaces manager)))))

(defun workspace-manager-previous (manager)
  "Activate the previous workspace, wrapping at the beginning."
  (workspace-manager-switch-index
   manager
   (mod (1- (workspace-manager-current-index manager))
        (length (workspace-manager-workspaces manager)))))

(defun workspace-manager-delete (manager &optional
                                           (index
                                             (workspace-manager-current-index
                                              manager)))
  "Delete the workspace at INDEX and return the new active workspace.

The final workspace cannot be deleted.  If the active index was removed, the
nearest remaining workspace becomes active."
  (when (= (length (workspace-manager-workspaces manager)) 1)
    (error "Cannot delete the final workspace"))
  (unless (and (integerp index)
               (<= 0 index)
               (< index (length (workspace-manager-workspaces manager))))
    (error "Workspace index is out of range: ~S" index))
  (setf (workspace-manager-workspaces manager)
        (loop for workspace in (workspace-manager-workspaces manager)
              for position from 0
              unless (= position index)
                collect workspace))
  (let ((current (workspace-manager-current-index manager)))
    (setf (workspace-manager-current-index manager)
          (cond
            ((> current index) (1- current))
            ((= current index) (min index
                                    (1- (length
                                         (workspace-manager-workspaces
                                          manager)))))
            (t current))))
  (workspace-manager-current manager))
