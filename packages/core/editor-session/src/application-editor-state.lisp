(in-package #:loom/core/editor-session)

(defun make-editor-state (&rest initargs)
  "Construct an EDITOR-STATE with a required session and a workspace manager.

Callers must provide the session that owns the feature slice state. When they
omit a workspace manager, the initial window tree becomes the main workspace."
  (let ((state (apply #'%make-editor-state initargs)))
    (unless (editor-session-p (editor-state-session state))
      (error "EDITOR-STATE requires an editor session"))
    (unless (editor-state-workspaces state)
      (setf (editor-state-workspaces state)
            (loom/feature/workspace:make-workspace-manager
             (editor-state-window-tree state)
             :name "main")))
    state))
