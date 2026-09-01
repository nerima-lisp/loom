;;;; packages/feature/session/src/application-session-snapshot.lisp
;;;;
;;;; Application layer: convert the live editor state to the validated
;;;; session snapshot owned by the domain-session-* files.
(in-package #:loom/feature/session)

(defun %session-buffer-snapshot (buffer)
  "Convert BUFFER's public state to a serializable snapshot."
  (multiple-value-bind (mark-line mark-column) (buffer-mark buffer)
    (make-session-buffer-snapshot
     :name (buffer-name buffer)
     :path (%session-path-string (buffer-path buffer))
     :text (buffer-text buffer)
     :point-line (buffer-point-line buffer)
     :point-column (buffer-point-column buffer)
     :mark-line mark-line
     :mark-column mark-column
     :modified-p (buffer-modified-p buffer))))

(defun %session-current-workspace (manager)
  (loom/feature/workspace:workspace-manager-current manager))

(defun %session-sync-active-workspace-tree (workspace)
  (setf (loom/feature/workspace:workspace-window-tree workspace)
        (editor-state-window-tree *editor-state*)))

(defun %session-snapshot-buffers (manager)
  (remove-duplicates
   (append (copy-list (%editor-buffers))
           (%session-workspace-live-buffers manager))
   :test #'eq))

(defun %session-command-history ()
  (and (editor-state-minibuffer *editor-state*)
       (minibuffer-history-entries (editor-state-minibuffer *editor-state*))))

(defun %session-snapshot-data (manager buffers)
  (make-session-snapshot
   :buffers (mapcar #'%session-buffer-snapshot buffers)
   :recent-files (copy-list (editor-state-recent-files *editor-state*))
   :bookmarks (%session-bookmark-snapshots)
   :command-history (%session-command-history)
   :workspaces (%session-workspace-snapshots manager buffers)
   :current-workspace-index
   (loom/feature/workspace:workspace-manager-current-index manager)))

(defun %session-snapshot-from-state ()
  "Return a validated snapshot of the current editor state."
  (let* ((manager (%session-workspace-manager))
         (current (%session-current-workspace manager)))
    ;; The visible editor tree is authoritative for the active workspace at
    ;; the instant a save starts; inactive workspaces already own their trees.
    (%session-sync-active-workspace-tree current)
    (let ((buffers (%session-snapshot-buffers manager)))
      (validate-session-snapshot (%session-snapshot-data manager buffers)))))
