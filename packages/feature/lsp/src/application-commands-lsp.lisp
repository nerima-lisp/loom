(in-package #:loom/feature/lsp)

(defun %lsp-start-discovery (buffer)
  (let ((path (or (buffer-path buffer) (truename "."))))
    (multiple-value-bind (command root configuration)
        (lsp-discover-command path)
      (values command (or root (%lsp-buffer-directory buffer)) configuration))))

(defun %lsp-start-with-command (command root buffer minibuffer)
  (if command
      (multiple-value-bind (session condition)
          (%lsp-start-session command root)
        (%lsp-report-start-result minibuffer session condition))
      (minibuffer-message minibuffer "LSP command cannot be empty")))

(defun lsp-start ()
  "Start an LSP session, offering the project-local command when available.

`.loom-lsp` is discovered before the prompt.  RET selects its command for
review; only an exact yes at the trust prompt runs it.  Typing a command
continues to override the discovered value explicitly."
  (let ((buffer (loom/core/window-tree:window-buffer (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*)))))
    (multiple-value-bind (discovered-command discovered-root configuration)
        (%lsp-start-discovery buffer)
      (loom/application:with-prompts
          (minibuffer (editor-state-minibuffer *editor-state*)
                      :on-cancel (minibuffer-message minibuffer "Quit"))
        ((typed-command (%lsp-command-prompt-string discovered-command)))
        (let ((override (%normalize-lsp-command typed-command nil)))
          (if (and discovered-command (null override))
              (%lsp-confirm-discovered-command
               discovered-command discovered-root configuration buffer minibuffer)
              (%lsp-start-with-command
               override discovered-root buffer minibuffer)))))))

(defun lsp-stop ()
  "Stop the current LSP session, if one exists."
  (let ((session (editor-state-lsp-session *editor-state*))
        (minibuffer (editor-state-minibuffer *editor-state*)))
    (if session
        (progn
          (lsp-session-stop session)
          (setf (editor-state-lsp-session *editor-state*) nil)
          (minibuffer-message minibuffer "LSP stopped."))
        (minibuffer-message minibuffer "No LSP session."))))

(defun %lsp-show-diagnostics (session buffer)
  (let ((diagnostics-buffer (%lsp-diagnostics-buffer)))
    (%replace-buffer-text
     diagnostics-buffer
     (%lsp-diagnostics-text
      buffer
      (lsp-session-diagnostics session buffer)))
    (loom/feature/window:window-set-buffer
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
  (let* ((session (editor-state-lsp-session *editor-state*))
         (buffer (loom/core/window-tree:window-buffer (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*))))
         (minibuffer (editor-state-minibuffer *editor-state*)))
    (cond
      ((null session)
       (minibuffer-message minibuffer "No LSP session."))
      ((null (buffer-path buffer))
       (minibuffer-message minibuffer
                            "LSP diagnostics need a file-backed buffer."))
      (t
       (%lsp-report-diagnostics-result session buffer minibuffer)))))
