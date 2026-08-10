;;;; packages/feature/session/src/application-commands-session.lisp
;;;;
;;;; Application layer: convert the live editor state to and from the
;;;; validated session snapshot owned by domain/session.lisp. The store itself
;;;; remains an infrastructure concern; these commands only choose the state
;;;; to persist and install a fully rebuilt state after a successful read.
(in-package #:loom/feature/session)

(defun %session-path-string (path)
  "Return PATH as a namestring, or NIL when PATH is NIL."
  (and path (namestring (pathname path))))

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

(defun %session-bookmark-snapshot (bookmark)
  "Convert one live bookmark to a serializable snapshot."
  (make-session-bookmark-snapshot
   :name (editor-bookmark-name bookmark)
   :path (%session-path-string (editor-bookmark-path bookmark))
   :buffer-name (or (editor-bookmark-buffer-name bookmark)
                    (and (editor-bookmark-buffer bookmark)
                         (buffer-name (editor-bookmark-buffer bookmark))))
   :line (editor-bookmark-line bookmark)
   :column (editor-bookmark-column bookmark)))

(defun %session-bookmark-snapshots ()
  "Return the current named bookmarks in deterministic order."
  (let ((bookmarks (editor-state-bookmarks *editor-state*)))
    (cond
      ((null bookmarks) nil)
      ((hash-table-p bookmarks)
       (sort
        (loop for bookmark being the hash-values of bookmarks
              collect (%session-bookmark-snapshot bookmark))
        #'string<
        :key #'session-bookmark-snapshot-name))
      (t
       (error "session snapshot: bookmarks must be a hash table")))))

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

(defun %session-workspace-manager ()
  "Return the live workspace manager, bridging pre-workspace test states."
  (or (editor-state-workspaces *editor-state*)
      (setf (editor-state-workspaces *editor-state*)
            (loom/feature/workspace:make-workspace-manager
             (editor-state-window-tree *editor-state*)))))

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
           (workspaces (%session-workspace-snapshots manager buffers))
           (current-snapshot (nth current-index workspaces)))
      (validate-session-snapshot
       (make-session-snapshot
        :buffers (mapcar #'%session-buffer-snapshot buffers)
        :layout (session-workspace-snapshot-layout current-snapshot)
        :selected-window-index
        (session-workspace-snapshot-selected-window-index current-snapshot)
        :recent-files (copy-list (editor-state-recent-files *editor-state*))
        :bookmarks (%session-bookmark-snapshots)
        :command-history
        (if (editor-state-minibuffer *editor-state*)
            (minibuffer-history-entries
             (editor-state-minibuffer *editor-state*))
            nil)
        :workspaces workspaces
        :current-workspace-index current-index)))))

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

(defun %restore-session-bookmark-buffer (snapshot buffers)
  "Find the restored buffer associated with bookmark SNAPSHOT."
  (or (and (session-bookmark-snapshot-path snapshot)
           (find (session-bookmark-snapshot-path snapshot)
                 buffers
                 :key (lambda (buffer)
                        (%session-path-string (buffer-path buffer)))
                 :test #'string=))
      (and (session-bookmark-snapshot-buffer-name snapshot)
           (find (session-bookmark-snapshot-buffer-name snapshot)
                 buffers
                 :key #'buffer-name
                 :test #'string=))))

(defun %restore-session-bookmarks (snapshots buffers)
  "Build a named bookmark table and reconnect bookmarks to BUFFERS when possible."
  (when snapshots
    (let ((bookmarks (make-hash-table :test #'equal)))
      (dolist (snapshot snapshots bookmarks)
        (let ((buffer (%restore-session-bookmark-buffer snapshot buffers)))
          (setf (gethash (session-bookmark-snapshot-name snapshot) bookmarks)
                (make-editor-bookmark
                 :name (session-bookmark-snapshot-name snapshot)
                 :buffer buffer
                 :path (and (session-bookmark-snapshot-path snapshot)
                            (pathname (session-bookmark-snapshot-path snapshot)))
                 :buffer-name (or (session-bookmark-snapshot-buffer-name snapshot)
                                  (and buffer (buffer-name buffer)))
                 :line (session-bookmark-snapshot-line snapshot)
                 :column (session-bookmark-snapshot-column snapshot))))))))

(defun %session-restorable-workspaces (snapshot buffers width height)
  "Build fresh workspace views from SNAPSHOT and restored BUFFERS."
  (let ((snapshots
          (or (session-snapshot-workspaces snapshot)
              (list (make-session-workspace-snapshot
                     :name "main"
                     :layout (session-snapshot-layout snapshot)
                     :selected-window-index
                     (session-snapshot-selected-window-index snapshot))))))
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
            (or (session-snapshot-current-workspace-index snapshot)
                0)))
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

(defun %session-path-present-p (path)
  "Return true when PATH contains a non-whitespace character."
  (and (stringp path)
       (plusp (length (string-trim '(#\Space #\Tab) path)))))

(defun save-session ()
  "Prompt for a path and save the current editor session there."
  (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                 :on-cancel (minibuffer-message minibuffer "Quit"))
      ((path "Save session to: "))
    (if (not (%session-path-present-p path))
        (minibuffer-message minibuffer "Session path cannot be empty")
        (handler-case
            (progn
              (session-store-write path (%session-snapshot-from-state))
              (minibuffer-message
               minibuffer
               (format nil "Session saved: ~A" path)))
          (error (condition)
            (minibuffer-message
             minibuffer
             (format nil "Could not save session: ~A" condition)))))))

(defun load-session ()
  "Prompt for a session path and restore it after a successful read."
  (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                 :on-cancel (minibuffer-message minibuffer "Quit"))
      ((path "Load session: "))
    (if (not (%session-path-present-p path))
        (minibuffer-message minibuffer "Session path cannot be empty")
        (handler-case
            (progn
              (%restore-session-snapshot (session-store-read path))
              (minibuffer-message
               minibuffer
               (format nil "Session loaded: ~A" path)))
          (error (condition)
            (minibuffer-message
             minibuffer
             (format nil "Could not load session: ~A" condition)))))))
