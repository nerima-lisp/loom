;;;; packages/feature/workspace/src/application-workspace-switch-support.lisp
;;;;
;;;; Application layer: shared workspace switching and minibuffer helpers.
(in-package #:loom/feature/workspace)

(defun %workspace-manager ()
  "Return the workspace manager owned by the current editor state."
  (or (editor-state-workspaces *editor-state*)
      (error "Editor state has no workspace manager")))

(defun %sync-current-workspace (manager)
  (setf (workspace-window-tree (workspace-manager-current manager))
        (editor-state-window-tree *editor-state*)))

(defun %activate-workspace (workspace)
  (setf (editor-state-window-tree *editor-state*)
        (workspace-window-tree workspace))
  workspace)

(defun %workspace-message (message)
  (let ((minibuffer (and *editor-state*
                         (editor-state-minibuffer *editor-state*))))
    (when minibuffer
      (minibuffer-message minibuffer message))))

(defun %workspace-messagef (control &rest arguments)
  (%workspace-message
   (apply #'format nil control arguments)))

(defun %current-selection-workspace-tree ()
  (let* ((current-tree (editor-state-window-tree *editor-state*))
         (selected-window (window-tree-selected-window current-tree)))
    (make-window-tree (window-buffer selected-window)
                      (window-tree-width current-tree)
                      (window-tree-height current-tree))))

(defun %workspace-name-candidates (input)
  (declare (ignore input))
  (mapcar #'workspace-name
          (workspace-manager-workspaces (%workspace-manager))))
