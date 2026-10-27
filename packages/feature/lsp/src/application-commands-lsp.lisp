(in-package #:loom/feature/lsp)

(defun %lsp-start-discovery (buffer)
  (let ((path (or (buffer-path buffer) (truename "."))))
    (multiple-value-bind (command root configuration identity)
        (lsp-discover-command path)
      (values command
              (or root
                  (loom/feature/project:project-find-root path)
                  (%lsp-buffer-directory buffer))
              configuration
              identity)))
)

(defun %lsp-start-with-command (command root buffer minibuffer &optional config-identity) (let ((editor-session (%lsp-current-editor-session))) (if command (multiple-value-bind (session condition) (%lsp-start-session command root (%lsp-language-id (loom/core/buffer:buffer-major-mode buffer)) config-identity editor-session) (when (and condition config-identity editor-session (member :feature/lsp (loom/core/editor-session:editor-session-slice-names editor-session))) (%lsp-record-autostart-failure editor-session config-identity)) (%lsp-report-start-result minibuffer session condition)) (minibuffer-message minibuffer "LSP command cannot be empty"))))

(defun lsp-start ()
  "Start an LSP session, offering the project-local command when available."
  (let ((buffer
          (loom/core/window-tree:window-buffer
           (loom/core/window-tree:window-tree-selected-window
            (editor-state-window-tree *editor-state*)))))
    (multiple-value-bind (discovered-command discovered-root
                          configuration identity)
        (%lsp-start-discovery buffer)
      (with-prompts
          (minibuffer (editor-state-minibuffer *editor-state*)
                      :on-cancel (minibuffer-message minibuffer "Quit"))
        ((typed-command (%lsp-command-prompt-string discovered-command)))
        (multiple-value-bind (override invalid-p)
            (%normalize-lsp-command typed-command nil)
          (cond
            (invalid-p
             (minibuffer-message
              minibuffer "LSP command contains unsupported shell syntax."))
            ((and discovered-command (null override))
             (%lsp-confirm-discovered-command
              discovered-command discovered-root configuration buffer
              minibuffer identity))
            (override
             (%lsp-start-with-command
              override discovered-root buffer minibuffer))
            (t
             (minibuffer-message minibuffer "LSP command cannot be empty")))))))
)

(defun lsp-stop ()
  "Stop the LSP session for the selected buffer."
  (let* ((buffer
           (loom/core/window-tree:window-buffer
            (loom/core/window-tree:window-tree-selected-window
             (editor-state-window-tree *editor-state*))))
         (session (%lsp-current-buffer-session buffer nil))
         (editor-session (%lsp-current-editor-session))
         (minibuffer (editor-state-minibuffer *editor-state*)))
    (if session
        (progn
          (when editor-session
            (%lsp-unregister-session editor-session session))
          (lsp-session-stop session)
          (when (eq (editor-state-lsp-session *editor-state*) session)
            (setf (editor-state-lsp-session *editor-state*) nil))
          (minibuffer-message minibuffer "LSP stopped."))
        (minibuffer-message minibuffer "No LSP session."))))

(defun %lsp-show-diagnostics (session buffer)
  (let ((diagnostics-buffer (%lsp-diagnostics-buffer)))
    (%replace-buffer-text
     diagnostics-buffer
     (%lsp-diagnostics-text
      buffer
      (lsp-session-diagnostics session buffer)))
    (loom/core/window-tree:window-set-buffer
     (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*))
     diagnostics-buffer)))

(defun %lsp-refresh-diagnostics (session buffer)
  (lsp-session-refresh session buffer)
  (when (lsp-session-last-error session)
    (%lsp-error-message session)))

(defun %lsp-report-diagnostics-result (session buffer minibuffer)
  (let ((error-message (%lsp-refresh-diagnostics session buffer)))
    (if error-message
        (minibuffer-message minibuffer
                            (format nil "LSP error: ~A" error-message))
        (progn
          (%lsp-show-diagnostics session buffer)
          (minibuffer-message minibuffer "LSP diagnostics refreshed.")))))

(defun lsp-diagnostics ()
  "Refresh and display diagnostics for the selected file-backed buffer."
  (let* ((buffer
           (loom/core/window-tree:window-buffer
            (loom/core/window-tree:window-tree-selected-window
             (editor-state-window-tree *editor-state*))))
         (session (%lsp-current-buffer-session buffer))
         (minibuffer (editor-state-minibuffer *editor-state*)))
    (cond
      ((null session)
       (minibuffer-message minibuffer "No LSP session."))
      ((null (buffer-path buffer))
       (minibuffer-message minibuffer
                           "LSP diagnostics need a file-backed buffer."))
      (t
       (%lsp-report-diagnostics-result session buffer minibuffer)))))
