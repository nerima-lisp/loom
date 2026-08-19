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

(defun %session-snapshot-from-state ()
  "Return a validated snapshot of the current editor state."
  (let* ((manager (%session-workspace-manager))
         (current (loom/feature/workspace:workspace-manager-current manager))
         (current-tree (editor-state-window-tree *editor-state*))
         (current-index
           (loom/feature/workspace:workspace-manager-current-index manager)))
    ;; The visible editor tree is authoritative for the active workspace at
    ;; the instant a save starts; inactive workspaces already own their trees.
    (setf (loom/feature/workspace:workspace-window-tree current) current-tree)
    (let* ((visible (%session-workspace-live-buffers manager))
           (buffers (remove-duplicates
                     (append (copy-list (%editor-buffers)) visible)
                     :test #'eq))
           (workspaces (%session-workspace-snapshots manager buffers)))
      (validate-session-snapshot
       (make-session-snapshot
        :buffers (mapcar #'%session-buffer-snapshot buffers)
        :recent-files (copy-list (editor-state-recent-files *editor-state*))
        :bookmarks (%session-bookmark-snapshots)
        :command-history
        (if (editor-state-minibuffer *editor-state*)
            (minibuffer-history-entries
             (editor-state-minibuffer *editor-state*))
            nil)
        :workspaces workspaces
        :current-workspace-index current-index)))))
