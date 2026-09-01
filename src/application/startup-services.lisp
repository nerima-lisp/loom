;;;; src/application/startup-services.lisp
;;;;
;;;; Startup-time infrastructure services that wrap the initial editor-state.
(in-package #:loom)

(defun %enable-concurrent-file-tree (state)
  "Replace STATE's synchronous file-tree lister with a cached runtime."
  (let* ((tree (editor-state-file-tree state))
         (lister (loom/feature/file-tree:file-tree-child-lister tree))
         (root (first (loom/feature/file-tree:file-tree-prefetch-paths tree)))
         (initial-entries (funcall lister root))
         (runtime (loom/feature/file-tree:make-loom-concurrent-runtime
                   :directory-lister lister)))
    (loom/feature/file-tree:loom-concurrent-runtime-prime-directory
     runtime root initial-entries)
    (loom/feature/file-tree:file-tree-install-child-lister
     tree
     (lambda (path)
       (multiple-value-bind (entries present-p)
           (loom/feature/file-tree:loom-concurrent-runtime-directory-entries
            runtime path)
         (when present-p entries))))
    (setf (editor-state-concurrent-runtime state) runtime)
    runtime))

(defun %shutdown-editor-services (state)
  "Stop asynchronous services attached to STATE."
  (let ((runtime (editor-state-concurrent-runtime state)))
    (when runtime
      (loom/feature/file-tree:loom-concurrent-runtime-shutdown runtime)))
  (let ((session (editor-state-lsp-session state)))
    (when session
      (loom/feature/lsp:lsp-session-stop session))))

(defun %run-loom-session (fd)
  "Load user init, run the terminal session, and translate errors into an
exit status for the CLI boundary."
  (handler-case
      (progn
        (loom/feature/user-init:load-user-init)
        (cl-tty-kit:with-terminal-session (stream :fd fd
                                           :raw-mode t
                                           :alternate-screen t
                                           :hide-cursor nil)
          (%run-event-loop stream *standard-input*))
        0)
    (error (condition)
      (let ((logger (log-kit:make-logger
                     :name "loom"
                     :handler (log-kit:make-text-handler :stream *error-output*)
                     :level log-kit:+level-error+)))
        (log-kit:log-error logger (princ-to-string condition)
                           :condition-type (type-of condition)))
      1)))
