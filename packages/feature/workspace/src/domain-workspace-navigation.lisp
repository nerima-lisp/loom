;;;; packages/feature/workspace/src/domain-workspace-navigation.lisp
;;;;
;;;; Public workspace domain API for current-workspace lookup and navigation.
(in-package #:loom/feature/workspace)

(defun workspace-manager-current (manager)
  "Return MANAGER's active workspace."
  (nth (workspace-manager-current-index manager)
       (workspace-manager-workspaces manager)))

(defun workspace-manager-current-name (manager)
  "Return MANAGER's active workspace name."
  (workspace-name (workspace-manager-current manager)))

(defun workspace-manager-switch-index (manager index)
  "Make the workspace at INDEX active and return it."
  (unless (%workspace-index-valid-p
           (workspace-manager-workspaces manager)
           index)
    (error "Workspace index is out of range: ~S" index))
  (setf (workspace-manager-current-index manager) index)
  (workspace-manager-current manager))

(defun workspace-manager-switch-name (manager name)
  "Make the workspace named NAME active and return it, or NIL if absent."
  (let ((index (position name (workspace-manager-workspaces manager)
                         :key #'workspace-name :test #'string-equal)))
    (when index
      (workspace-manager-switch-index manager index))))

(defmacro %define-workspace-stepper (name docstring delta)
  `(defun ,name (manager)
     ,docstring
     (workspace-manager-switch-index
      manager
      (mod (+ (workspace-manager-current-index manager) ,delta)
           (length (workspace-manager-workspaces manager))))))

(%define-workspace-stepper
 workspace-manager-next
 "Activate the next workspace, wrapping at the end."
 1)

(%define-workspace-stepper
 workspace-manager-previous
 "Activate the previous workspace, wrapping at the beginning."
 -1)
