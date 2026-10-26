(in-package #:loom/feature/session)

(defun %session-buffer-path (snapshot)
  (and (session-buffer-snapshot-path snapshot)
       (pathname (session-buffer-snapshot-path snapshot))))

(defun %restore-session-buffer-position (buffer snapshot)
  (buffer-set-point buffer
                    (session-buffer-snapshot-point-line snapshot)
                    (session-buffer-snapshot-point-column snapshot))
  (when (session-buffer-snapshot-mark-line snapshot)
    (buffer-set-mark buffer
                     (session-buffer-snapshot-mark-line snapshot)
                     (session-buffer-snapshot-mark-column snapshot))))

(defun %restore-session-buffer (snapshot)
  "Build a fresh buffer from one validated session buffer SNAPSHOT."
  (let ((buffer
         (make-buffer :name
                      (session-buffer-snapshot-name snapshot)
                      :path
                      (%session-buffer-path snapshot)
                      :initial-content
                      (session-buffer-snapshot-text snapshot))))
    (%restore-session-buffer-position buffer snapshot)
    (when (session-buffer-snapshot-modified-p snapshot)
      (buffer-mark-modified buffer))
    buffer))
(defun %restore-session-file-tree-expansions (tree paths)
  (loop with pending = (mapcar #'pathname paths)
        while pending
        do (let ((deferred nil)
                 (expanded-p nil))
             (dolist (path pending)
               (if (eq (loom/feature/file-tree:file-tree-entry-kind tree path)
                       :directory)
                   (progn
                     (loom/feature/file-tree:file-tree-toggle-expand tree path)
                     (setf expanded-p t))
                   (push path deferred)))
             (setf pending (nreverse deferred))
             (unless expanded-p
               (return))))
  tree)
(defun %restore-session-file-tree-selection (tree selected-path)
  (when selected-path
    (let ((selected-directory
            (and (eq (loom/feature/file-tree:file-tree-entry-kind
                      tree (pathname selected-path))
                     :directory)
                 (host-kit:ensure-directory-pathname
                  (pathname selected-path)))))
      (loop for entry in (loom/feature/file-tree:file-tree-entries tree)
            for position from 0
            for entry-path = (car entry)
            when (or
                  (string= selected-path
                           (%session-path-string entry-path))
                  (and selected-directory
                       (equal selected-directory
                              (host-kit:ensure-directory-pathname
                               entry-path))))
              do (loop repeat (1+ position)
                       do (loom/feature/file-tree:file-tree-move-selection
                           tree :down))
                 (return))))
  tree)
(defun %restore-session-file-tree (snapshot current-tree)
  (if snapshot
      (let* ((root-string
               (session-file-tree-snapshot-root-path snapshot))
             (raw-root
               (and (stringp root-string) (pathname root-string))))
        (unless (and (stringp root-string)
                     (plusp (length root-string))
                     (not (wild-pathname-p raw-root)))
          (error "session restore: invalid file-tree root path ~S"
                 root-string))
        (unless (host-kit:directory-exists-p raw-root)
          (return-from %restore-session-file-tree
            (values current-tree
                    (format nil "File-tree root not found: ~A"
                            root-string))))
        (multiple-value-bind (root-path expanded-paths selected-path)
            (%validate-session-file-tree-paths snapshot)
          (let* ((tree
                   (loom/feature/file-tree:make-file-tree root-path))
                 (runtime
                   (loom/core/editor-session:editor-state-concurrent-runtime
                    *editor-state*)))
            (loom/feature/file-tree:file-tree-install-child-lister
             tree (function loom/feature/file-tree:loom-fs-list-directory))
            (%restore-session-file-tree-expansions tree expanded-paths)
            (%restore-session-file-tree-selection tree selected-path)
            (when (session-file-tree-snapshot-visible-p snapshot)
              (loom/feature/file-tree:file-tree-toggle tree))
            (when (and runtime current-tree)
              (loom/feature/file-tree:file-tree-install-child-lister
               tree (loom/feature/file-tree:file-tree-child-lister current-tree)))
            (values tree nil))))
      (values current-tree nil)))
(defun %validate-session-file-tree-paths (snapshot)
  (let* ((root-string
           (session-file-tree-snapshot-root-path snapshot))
         (raw-root
           (and (stringp root-string) (pathname root-string))))
    (unless (and (stringp root-string)
                 (plusp (length root-string))
                 (not (wild-pathname-p raw-root)))
      (error "session restore: invalid file-tree root path ~S" root-string))
    (let* ((root-path
             (host-kit:ensure-directory-pathname (truename raw-root)))
           (root-directory (pathname-directory root-path)))
      (labels ((normalize-pathname (path-string)
                 (unless (and (stringp path-string)
                              (plusp (length path-string)))
                   (error "session restore: invalid file-tree path ~S"
                          path-string))
                 (let ((raw-path (pathname path-string)))
                   (when (wild-pathname-p raw-path)
                     (error "session restore: invalid file-tree path ~S"
                            path-string))
                   (let* ((absolute-path
                            (if (eq (first (pathname-directory raw-path))
                                    :absolute)
                                raw-path
                                (merge-pathnames raw-path (truename "."))))
                          (resolved-path
                            (if (probe-file absolute-path)
                                (truename absolute-path)
                                absolute-path))
                          (normalized-directory
                            (cons
                             :absolute
                             (loop with parts = nil
                                   for part in
                                   (rest (pathname-directory resolved-path))
                                   do (if (member part (list :up :back)
                                                  :test (function eq))
                                          (when parts (pop parts))
                                          (push part parts))
                                   finally (return (nreverse parts))))))
                     (make-pathname :directory normalized-directory
                                    :defaults resolved-path))))
               (within-root-p (path)
                 (let ((path-directory (pathname-directory path)))
                   (and (equal (pathname-host root-path)
                               (pathname-host path))
                        (equal (pathname-device root-path)
                               (pathname-device path))
                        (notany (lambda (part)
                                  (member part (list :up :back)
                                          :test (function eq)))
                                root-directory)
                        (notany (lambda (part)
                                  (member part (list :up :back)
                                          :test (function eq)))
                                path-directory)
                        (<= (length root-directory) (length path-directory))
                        (loop for root-part in root-directory
                              for path-part in path-directory
                              always (equal root-part path-part)))))
               (validated-path (path-string)
                 (let ((path (normalize-pathname path-string)))
                   (unless (within-root-p path)
                     (error
                      "session restore: file-tree path is outside saved root ~S: ~S"
                      root-string path-string))
                   path)))
        (let ((expanded-paths
                (mapcar (lambda (path)
                          (namestring (validated-path path)))
                        (session-file-tree-snapshot-expanded-paths snapshot)))
              (selected-path
                (when (session-file-tree-snapshot-selected-path snapshot)
                  (namestring
                   (validated-path
                    (session-file-tree-snapshot-selected-path snapshot))))))
          (values root-path expanded-paths selected-path))))))

(defun %restore-session-snapshot (snapshot)
  "Install SNAPSHOT after rebuilding every buffer and window in advance."
  (validate-session-snapshot snapshot)
  (let* ((old-tree (editor-state-window-tree *editor-state*))
         (old-file-tree
           (loom/core/editor-session:editor-state-file-tree *editor-state*))
         (buffers
           (mapcar (function %restore-session-buffer)
                   (session-snapshot-buffers snapshot)))
         (width (loom/core/window-tree:window-tree-width old-tree))
         (height (loom/core/window-tree:window-tree-height old-tree))
         (workspaces
           (%session-restorable-workspaces snapshot buffers width height))
         (manager
           (loom/feature/workspace:make-workspace-manager-from-workspaces
            workspaces
            :current-index
            (session-snapshot-current-workspace-index snapshot)))
         (tree
           (loom/feature/workspace:workspace-window-tree
            (loom/feature/workspace:workspace-manager-current manager)))
         (bookmarks
           (%restore-session-bookmarks
            (session-snapshot-bookmarks snapshot) buffers)))
    (multiple-value-bind (file-tree warning)
        (%restore-session-file-tree
         (session-snapshot-file-tree snapshot) old-file-tree)
      (let ((candidate-state
              (loom/core/editor-session:make-editor-state
               :session (editor-state-session *editor-state*)
               :window-tree old-tree
               :file-tree file-tree
               :concurrent-runtime
               (loom/core/editor-session:editor-state-concurrent-runtime
                *editor-state*))))
        (unless warning
          (loom/feature/file-tree:refresh-file-tree-runtime candidate-state)))
      (%install-restored-session-state
       snapshot buffers bookmarks manager tree file-tree)
      (values tree warning))))

(defun %install-restored-session-state
    (snapshot buffers bookmarks manager tree file-tree)
  (progn
    (dolist (buffer (registered-buffers (editor-state-session *editor-state*)))
      (unregister-buffer (editor-state-session *editor-state*) buffer))
    (dolist (buffer (reverse (copy-list buffers)))
      (register-buffer (editor-state-session *editor-state*) buffer))
    (setf (editor-state-recent-files *editor-state*)
          (copy-list (session-snapshot-recent-files snapshot))
          (editor-state-bookmarks *editor-state*) bookmarks
          (editor-state-workspaces *editor-state*) manager
          (editor-state-window-tree *editor-state*) tree
          (loom/core/editor-session:editor-state-file-tree *editor-state*)
          file-tree))
  (when (editor-state-minibuffer *editor-state*)
    (minibuffer-set-history-entries (editor-state-minibuffer *editor-state*)
                                    (session-snapshot-command-history snapshot))))
