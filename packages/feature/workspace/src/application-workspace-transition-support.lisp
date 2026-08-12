;;;; packages/feature/workspace/src/application-workspace-transition-support.lisp
;;;;
;;;; Application layer: shared workspace transition sequencing.
(in-package #:loom/feature/workspace)

(defun %announce-workspace (workspace)
  (%workspace-messagef "Workspace: ~A" (workspace-name workspace))
  workspace)

(defun %create-and-switch-workspace (manager)
  "Create a workspace from the current selection, then activate and announce it."
  (let ((workspace (workspace-manager-create
                    manager
                    (%current-selection-workspace-tree))))
    ;; Save the old tree before changing the manager's active index.  Creation
    ;; appends without activating so the domain operation remains useful to
    ;; callers that want to prepare a workspace before switching to it.
    (%switch-workspace-with
     manager
     (lambda (workspace-manager)
       (workspace-manager-switch-name workspace-manager
                                      (workspace-name workspace))))))

(defun %switch-workspace-with (manager switcher)
  "Persist the current view, invoke SWITCHER, then activate and announce it."
  (%sync-current-workspace manager)
  (let ((workspace (funcall switcher manager)))
    (when workspace
      (%announce-workspace (%activate-workspace workspace)))))

(defun %switch-workspace-named (manager name)
  "Switch MANAGER to NAME, announcing success and reporting unknown names."
  (or (%switch-workspace-with
       manager
       (lambda (workspace-manager)
         (workspace-manager-switch-name workspace-manager name)))
      (progn
        (%workspace-messagef "No such workspace: ~A" name)
        nil)))

(defun %delete-current-workspace (manager)
  "Persist the current view, delete the active workspace, then activate the survivor."
  (%sync-current-workspace manager)
  (let* ((current (workspace-manager-current manager))
         (workspace (workspace-manager-delete manager)))
    (%activate-workspace workspace)
    (%workspace-messagef "Deleted workspace: ~A"
                         (workspace-name current))
    workspace))
