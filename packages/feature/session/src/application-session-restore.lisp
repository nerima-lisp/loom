;;;; packages/feature/session/src/application-session-restore.lisp
;;;;
;;;; Application layer: rebuild live editor state from the validated
;;;; session snapshot owned by the domain-session-* files.
(in-package #:loom/feature/session)

(defun %restore-session-buffer (snapshot)
  "Build a fresh buffer from one validated session buffer SNAPSHOT."
  (let ((buffer
          (make-buffer
           :name (session-buffer-snapshot-name snapshot)
           :path (and (session-buffer-snapshot-path snapshot)
                      (pathname (session-buffer-snapshot-path snapshot)))
           :initial-content (session-buffer-snapshot-text snapshot))))
    (buffer-set-point buffer
                      (session-buffer-snapshot-point-line snapshot)
                      (session-buffer-snapshot-point-column snapshot))
    (when (session-buffer-snapshot-mark-line snapshot)
      (buffer-set-mark buffer
                       (session-buffer-snapshot-mark-line snapshot)
                       (session-buffer-snapshot-mark-column snapshot)))
    (when (session-buffer-snapshot-modified-p snapshot)
      (buffer-mark-modified buffer))
    buffer))

(defun %restore-session-snapshot (snapshot)
  "Install SNAPSHOT after rebuilding every buffer and window in advance."
  (validate-session-snapshot snapshot)
  (let* ((old-tree (editor-state-window-tree *editor-state*))
         (buffers (mapcar #'%restore-session-buffer
                          (session-snapshot-buffers snapshot)))
         (width (loom/feature/window:window-tree-width old-tree))
         (height (loom/feature/window:window-tree-height old-tree))
         (workspaces (%session-restorable-workspaces
                      snapshot buffers width height))
         (manager
           (loom/feature/workspace:make-workspace-manager-from-workspaces
            workspaces
            :current-index
            (session-snapshot-current-workspace-index snapshot)))
         (tree (loom/feature/workspace:workspace-window-tree
                (loom/feature/workspace:workspace-manager-current manager)))
         (bookmarks (%restore-session-bookmarks
                     (session-snapshot-bookmarks snapshot)
                     buffers)))
    (setf (editor-state-buffers *editor-state*) buffers
          (editor-state-recent-files *editor-state*)
          (copy-list (session-snapshot-recent-files snapshot))
          (editor-state-bookmarks *editor-state*) bookmarks
          (editor-state-workspaces *editor-state*) manager
          (editor-state-window-tree *editor-state*) tree)
    (when (editor-state-minibuffer *editor-state*)
      (minibuffer-set-history-entries
       (editor-state-minibuffer *editor-state*)
       (session-snapshot-command-history snapshot)))
    tree))
