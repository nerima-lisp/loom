(in-package #:loom/feature/session)

(defun %session-sexp (snapshot)
  (validate-session-snapshot snapshot)
  (list :loom-session +loom-session-version+
        :buffers (mapcar #'%session-sexp-buffer
                         (session-snapshot-buffers snapshot))
        :recent-files (session-snapshot-recent-files snapshot)
        :bookmarks (mapcar #'%session-sexp-bookmark
                           (session-snapshot-bookmarks snapshot))
        :command-history (session-snapshot-command-history snapshot)
        :workspaces (mapcar #'%session-sexp-workspace
                            (session-snapshot-workspaces snapshot))
        :current-workspace-index
        (session-snapshot-current-workspace-index snapshot)
        :file-tree (and (session-snapshot-file-tree snapshot)
                        (%session-sexp-file-tree
                         (session-snapshot-file-tree snapshot)))))

(defun %session-required-list (value message)
  (unless (%session-proper-list-p value)
    (error "session: ~A must be a proper list" message))
  value)

(defun %session-required-string-list (value message)
  (unless (and (%session-proper-list-p value)
               (every #'stringp value))
    (error "session: ~A must be a list of strings" message))
  value)

(defun %session-snapshot-from-sexp-fields
    (serialized-buffers recent-files serialized-bookmarks command-history
     serialized-workspaces current-index serialized-file-tree)
  (%session-required-list serialized-buffers ":buffers")
  (%session-required-string-list recent-files ":recent-files")
  (%session-required-list serialized-bookmarks ":bookmarks")
  (%session-required-string-list command-history ":command-history")
  (%session-required-list serialized-workspaces ":workspaces")
  (validate-session-snapshot
   (make-session-snapshot
    :buffers (mapcar #'%session-buffer-from-sexp serialized-buffers)
    :recent-files recent-files
    :bookmarks (mapcar #'%session-bookmark-from-sexp serialized-bookmarks)
    :command-history command-history
    :workspaces (mapcar #'%session-workspace-from-sexp serialized-workspaces)
    :current-workspace-index current-index
    :file-tree (and serialized-file-tree
                    (%session-file-tree-from-sexp serialized-file-tree)))))

(defun %session-from-sexp (value)
  (unless (%session-keyword-plist-p value)
    (%session-error "session: expected a keyword plist, got ~S" value))
  (let* ((version (%session-plist-value value :loom-session))
         (expected-keys
           (cond
             ((eql version 5) +loom-session-v5-top-level-keys+)
             ((eql version +loom-session-version+)
              +loom-session-top-level-keys+)
             (t (%session-error "session: unsupported version ~S" version)))))
    (%validate-session-plist value expected-keys "session")
    (%session-snapshot-from-sexp-fields
     (%session-plist-value value :buffers)
     (%session-plist-value value :recent-files)
     (%session-plist-value value :bookmarks)
     (%session-plist-value value :command-history)
     (%session-plist-value value :workspaces)
     (%session-plist-value value :current-workspace-index)
     (when (eql version +loom-session-version+)
       (%session-plist-value value :file-tree)))))
