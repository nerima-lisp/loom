;;;; packages/feature/workspace/src/application-commands-workspace.lisp
;;;;
;;;; Application layer: workspace commands synchronize the active workspace's
;;;; window tree with EDITOR-STATE before changing views.
(in-package #:loom/feature/workspace)

(defmacro %define-workspace-cycle-command (name switcher docstring)
  `(defun ,name ()
     ,docstring
     (%switch-workspace-with
      (%workspace-manager)
      #',switcher)))

(defun new-workspace ()
  "Create a workspace containing the selected buffer and switch to it."
  (%create-and-switch-workspace (%workspace-manager)))

(%define-workspace-cycle-command
 next-workspace
 workspace-manager-next
 "Switch to the next workspace, wrapping at the end.")

(%define-workspace-cycle-command
 previous-workspace
 workspace-manager-previous
 "Switch to the previous workspace, wrapping at the beginning.")

(defun switch-workspace ()
  "Prompt for a workspace name and switch to it."
  (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                 :on-cancel (minibuffer-message minibuffer "Quit"))
      ((name "Switch to workspace: "
             :completion-function #'%workspace-name-candidates))
    ;; Save the old view before changing the manager's active index.  The
    ;; selected workspace owns the tree that will become visible next.
    (%switch-workspace-named (%workspace-manager) name)))

(defun kill-workspace ()
  "Delete the current workspace, refusing to remove the final one."
  (let ((manager (%workspace-manager)))
    (handler-case
        (%delete-current-workspace manager)
      (error (condition)
        (%workspace-messagef "~A" condition)
        nil))))
