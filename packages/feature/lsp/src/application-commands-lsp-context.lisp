;;;; packages/feature/lsp/src/application-commands-lsp-context.lisp
;;;;
;;;; Shared request context and user-facing message handling for LSP commands.
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
addresses documents by URI, and a buffer that was never saved has none."
  (let* ((session (%lsp-navigation-session))
         (buffer (loom/application:%selected-buffer))
         (path (and buffer (loom:buffer-path buffer))))
    (when (and session
               (lsp-session-initialized-p session)
               (not (lsp-session-closed-p session))
               path)
      (values session buffer (lsp-path-uri path)
              (loom:buffer-point-line buffer)
              (loom:buffer-point-column buffer)))))
