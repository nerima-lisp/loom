;;;; packages/feature/lsp/src/application-commands-lsp.lisp
;;;;
;;;; Application-layer commands for starting an LSP child process and showing
;;;; diagnostics.  The session protocol owns transport, document versions,
;;;; and diagnostic values; this file only turns those values into editor
;;;; use-cases and a normal Loom buffer.
(in-package #:loom/feature/lsp)

(defun lsp-start ()
  "Start an LSP session, offering the project-local command when available.

`.loom-lsp` is discovered before the prompt.  Pressing RET accepts the first
usable command line from that file; typing a command continues to override
the discovered value explicitly."
  (let* ((buffer (loom/application:%selected-buffer))
         (path (or (buffer-path buffer) (truename ".")))
         (discovered-command nil)
         (discovered-root nil))
    (multiple-value-setq (discovered-command discovered-root)
      (lsp-discover-command path))
    (loom/application:with-prompts
        (minibuffer (editor-state-minibuffer *editor-state*)
                         :on-cancel (minibuffer-message minibuffer "Quit"))
        ((typed-command (%lsp-command-prompt-string discovered-command)))
      (let ((command (%normalize-lsp-command typed-command discovered-command)))
        (if command
            (multiple-value-bind (session condition)
                (%lsp-start-session
                 command
                 (or discovered-root (%lsp-buffer-directory buffer)))
              (%lsp-report-start-result minibuffer session condition))
            (minibuffer-message minibuffer "LSP command cannot be empty"))))))

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
     (loom/application:%selected-window)
     diagnostics-buffer)))

(defun lsp-diagnostics ()
  "Refresh and display diagnostics for the selected file-backed buffer."
  (let* ((session (editor-state-lsp-session *editor-state*))
         (buffer (loom/application:%selected-buffer))
         (minibuffer (editor-state-minibuffer *editor-state*)))
    (cond
      ((null session)
       (minibuffer-message minibuffer "No LSP session."))
      ((null (buffer-path buffer))
       (minibuffer-message minibuffer
                            "LSP diagnostics need a file-backed buffer."))
      (t
       (lsp-session-refresh session buffer)
       (if (lsp-session-last-error session)
           (minibuffer-message
            minibuffer
            (format nil "LSP error: ~A" (%lsp-error-message session)))
           (progn
             (%lsp-show-diagnostics session buffer)
             (minibuffer-message minibuffer "LSP diagnostics refreshed.")))))))
