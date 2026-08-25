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
      (unless (listp serialized-buffers)
        (error "session: :buffers must be a proper list"))
      (unless (and (listp recent-files)
                   (every #'stringp recent-files))
        (error "session: :recent-files must be a list of strings"))
      (unless (listp serialized-bookmarks)
        (error "session: :bookmarks must be a proper list"))
      (unless (and (listp command-history)
                   (every #'stringp command-history))
        (error "session: :command-history must be a list of strings"))
      (unless (listp serialized-workspaces)
        (error "session: :workspaces must be a proper list"))
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
