(in-package #:loom/feature/lsp)

(defun %lsp-navigation-session ()
  (loom:editor-state-lsp-session loom:*editor-state*))

(defun %lsp-navigation-minibuffer ()
  (loom:editor-state-minibuffer loom:*editor-state*))

(defun %lsp-navigation-message (text)
  (let ((minibuffer (%lsp-navigation-minibuffer)))
    (when minibuffer
      (loom:minibuffer-message minibuffer text)))
  nil)

(defun %lsp-navigation-context ()
  "Return (VALUES SESSION BUFFER URI LINE CHARACTER) when a request can be sent.

A request needs an initialized session and a file-backed buffer: a server
addresses documents by URI, and a buffer with no associated path has none."
  (let* ((session (%lsp-navigation-session))
         (buffer (loom/core/window-tree:window-buffer (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*))))
         (path (and buffer (loom:buffer-path buffer))))
    (when (and session
               (not (lsp-session-initialized-p session))
               (not (lsp-session-closed-p session)))
      (%lsp-await-initialized session))
    (when (and session
               (lsp-session-initialized-p session)
               (not (lsp-session-closed-p session))
               path)
      (values session buffer (lsp-path-uri path)
              (loom:buffer-point-line buffer)
              (loom:buffer-point-column buffer)))))
