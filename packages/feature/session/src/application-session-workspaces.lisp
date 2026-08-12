;;;; packages/feature/session/src/application-session-workspaces.lisp
;;;;
;;;; Application helpers for converting workspace/window state to and from
;;;; validated session snapshots.
(in-package #:loom/feature/session)

(defun %session-indexed-layout (layout buffers)
  "Replace each buffer in LAYOUT with its index in BUFFERS."
  (case (first layout)
    (:leaf
     (let ((index (position (second layout) buffers :test #'eq)))
       (unless index
         (error "session snapshot: layout references an unregistered buffer ~S"
                (second layout)))
       (list :leaf index (third layout))))
    (:split
     (list :split
           (second layout)
           (%session-indexed-layout (third layout) buffers)
           (%session-indexed-layout (fourth layout) buffers)))
    (otherwise
     (error "session snapshot: unknown window layout node ~S" layout))))

(defun %restore-session-layout (layout buffers)
  "Replace buffer indexes in indexed LAYOUT with restored BUFFERS."
  (case (first layout)
    (:leaf
     (list :leaf (nth (second layout) buffers) (third layout)))
    (:split
     (list :split
           (second layout)
           (%restore-session-layout (third layout) buffers)
           (%restore-session-layout (fourth layout) buffers)))
    (otherwise
     (error "session restore: unknown window layout node ~S" layout))))

(defun %session-workspace-manager ()
  "Return the workspace manager owned by the live editor state."
  (or (editor-state-workspaces *editor-state*)
      (error "Editor state has no workspace manager")))

(defun %session-workspace-live-buffers (manager)
  "Return buffers displayed by every workspace in MANAGER."
  (mapcan (lambda (workspace)
            (mapcar #'loom/feature/window:window-buffer
                    (loom/feature/window:window-tree-windows
                     (loom/feature/workspace:workspace-window-tree workspace))))
          (loom/feature/workspace:workspace-manager-workspaces manager)))

(defun %session-workspace-snapshots (manager buffers)
  "Convert every live workspace view to an indexed session snapshot."
  (mapcar
   (lambda (workspace)
     (let ((tree (loom/feature/workspace:workspace-window-tree workspace)))
       (make-session-workspace-snapshot
        :name (loom/feature/workspace:workspace-name workspace)
        :layout (%session-indexed-layout
                 (loom/feature/window:window-tree-layout tree) buffers)
        :selected-window-index
        (loom/feature/window:window-tree-selected-index tree))))
   (loom/feature/workspace:workspace-manager-workspaces manager)))

(defun %session-restorable-workspaces (snapshot buffers width height)
  "Build fresh workspace views from SNAPSHOT and restored BUFFERS."
  (let ((snapshots (session-snapshot-workspaces snapshot)))
    (mapcar
     (lambda (workspace-snapshot)
       (loom/feature/workspace:make-workspace
        :name (session-workspace-snapshot-name workspace-snapshot)
        :window-tree
        (make-window-tree-from-layout
         (%restore-session-layout
          (session-workspace-snapshot-layout workspace-snapshot)
          buffers)
         width
         height
         :selected-index
         (session-workspace-snapshot-selected-window-index
          workspace-snapshot))))
     snapshots)))
