;;;; packages/feature/session/src/infrastructure-session-codec.lisp
;;;;
;;;; Session snapshot serialization and validation helpers shared by the
;;;; persistent session store.
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
        (session-snapshot-current-workspace-index snapshot)))

(defun %session-required-list (value message)
  (unless (listp value)
    (error "session: ~A must be a proper list" message))
  value)

(defun %session-required-string-list (value message)
  (unless (and (listp value)
               (every #'stringp value))
    (error "session: ~A must be a list of strings" message))
  value)

(defun %session-from-sexp (value)
  (%validate-session-plist value +loom-session-top-level-keys+ "session")
  (let ((version (%session-plist-value value :loom-session)))
    (unless (eql version +loom-session-version+)
      (error "session: unsupported version ~S" version))
    (let ((serialized-buffers (%session-plist-value value :buffers))
          (recent-files (%session-plist-value value :recent-files))
          (serialized-bookmarks (%session-plist-value value :bookmarks))
          (command-history (%session-plist-value value :command-history))
          (serialized-workspaces (%session-plist-value value :workspaces))
          (current-index
            (%session-plist-value value :current-workspace-index)))
      (%session-required-list serialized-buffers ":buffers")
      (%session-required-string-list recent-files ":recent-files")
      (%session-required-list serialized-bookmarks ":bookmarks")
      (%session-required-string-list command-history ":command-history")
      (%session-required-list serialized-workspaces ":workspaces")
      (validate-session-snapshot
       (make-session-snapshot
        :buffers (mapcar #'%session-buffer-from-sexp serialized-buffers)
        :recent-files recent-files
        :bookmarks (mapcar #'%session-bookmark-from-sexp
                           serialized-bookmarks)
        :command-history command-history
        :workspaces (mapcar #'%session-workspace-from-sexp
                            serialized-workspaces)
        :current-workspace-index current-index)))))
