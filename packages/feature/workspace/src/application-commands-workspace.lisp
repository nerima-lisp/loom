;;;; packages/feature/workspace/src/application-commands-workspace.lisp
;;;;
;;;; Application layer: workspace commands synchronize the active workspace's
;;;; window tree with EDITOR-STATE before changing views.
(in-package #:loom/feature/workspace)

(defun %workspace-manager ()
  "Return the current editor's manager, creating a legacy-compatible one if
the state was built by a caller that predates the workspace slot."
  (or (editor-state-workspaces *editor-state*)
      (setf (editor-state-workspaces *editor-state*)
            (make-workspace-manager (editor-state-window-tree *editor-state*)))))

(defun %sync-current-workspace (manager)
  (setf (workspace-window-tree (workspace-manager-current manager))
        (editor-state-window-tree *editor-state*)))

(defun %select-workspace (manager workspace)
  (%sync-current-workspace manager)
  (setf (editor-state-window-tree *editor-state*)
        (workspace-window-tree workspace))
  workspace)

(defun %workspace-message (message)
  (let ((minibuffer (and *editor-state*
                         (editor-state-minibuffer *editor-state*))))
    (when minibuffer
      (minibuffer-message minibuffer message))))

(defun new-workspace ()
  "Create a workspace containing the selected buffer and switch to it."
  (let* ((manager (%workspace-manager))
         (current-tree (editor-state-window-tree *editor-state*))
         (selected-window (window-tree-selected-window current-tree))
         (buffer (window-buffer selected-window))
         (workspace (workspace-manager-create
                     manager
                     (make-window-tree buffer
                                       (window-tree-width current-tree)
                                       (window-tree-height current-tree)))))
    ;; Save the old tree before changing the manager's active index.  Creation
    ;; appends without activating so the domain operation remains useful to
    ;; callers that want to prepare a workspace before switching to it.
    (%sync-current-workspace manager)
    (workspace-manager-switch-name manager (workspace-name workspace))
    (setf (editor-state-window-tree *editor-state*)
          (workspace-window-tree workspace))
    (%workspace-message
     (format nil "Workspace: ~A" (workspace-name workspace)))
    workspace))

(defun next-workspace ()
  "Switch to the next workspace, wrapping at the end."
  (let ((manager (%workspace-manager)))
    (%sync-current-workspace manager)
    (let ((workspace (workspace-manager-next manager)))
      (setf (editor-state-window-tree *editor-state*)
            (workspace-window-tree workspace))
      (%workspace-message
       (format nil "Workspace: ~A" (workspace-name workspace)))
      workspace)))

(defun previous-workspace ()
  "Switch to the previous workspace, wrapping at the beginning."
  (let ((manager (%workspace-manager)))
    (%sync-current-workspace manager)
    (let ((workspace (workspace-manager-previous manager)))
      (setf (editor-state-window-tree *editor-state*)
            (workspace-window-tree workspace))
      (%workspace-message
       (format nil "Workspace: ~A" (workspace-name workspace)))
      workspace)))

(defun %workspace-name-candidates (input)
  (declare (ignore input))
  (mapcar #'workspace-name
          (workspace-manager-workspaces (%workspace-manager))))

(defun switch-workspace ()
  "Prompt for a workspace name and switch to it."
  (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                 :on-cancel (minibuffer-message minibuffer "Quit"))
      ((name "Switch to workspace: "
             :completion-function #'%workspace-name-candidates))
    (let ((manager (%workspace-manager)))
      ;; Save the old view before changing the manager's active index.  The
      ;; selected workspace owns the tree that will become visible next.
      (%sync-current-workspace manager)
      (let ((workspace (workspace-manager-switch-name manager name)))
        (if workspace
            (progn
              (setf (editor-state-window-tree *editor-state*)
                    (workspace-window-tree workspace))
              (minibuffer-message
               minibuffer
               (format nil "Workspace: ~A" (workspace-name workspace))))
            (minibuffer-message
             minibuffer
             (format nil "No such workspace: ~A" name)))))))

(defun kill-workspace ()
  "Delete the current workspace, refusing to remove the final one."
  (let* ((manager (%workspace-manager))
         (current (workspace-manager-current manager)))
    (handler-case
        (progn
          (%sync-current-workspace manager)
          (let ((workspace (workspace-manager-delete manager)))
            (setf (editor-state-window-tree *editor-state*)
                  (workspace-window-tree workspace))
            (%workspace-message
             (format nil "Deleted workspace: ~A"
                     (workspace-name current)))
            workspace))
      (error (condition)
        (%workspace-message (format nil "~A" condition))
        nil))))
