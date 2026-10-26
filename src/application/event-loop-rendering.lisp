(in-package #:loom)

(defun %render-event-loop-frame (stream render-frame-function)
  "Refresh application state before presenting a frame through the root adapter."
  (loom/feature/terminal:poll-terminal-sessions *editor-state*)
  (loom/feature/file-tree:refresh-file-tree-runtime *editor-state*)
  (let ((session (editor-state-lsp-session *editor-state*))
        (buffer
         (loom/core/window-tree:window-buffer
          (loom/core/window-tree:window-tree-selected-window
           (editor-state-window-tree *editor-state*)))))
    (when (and session (buffer-path buffer))
      (loom/feature/lsp:lsp-session-refresh session buffer)))
  (funcall render-frame-function stream))

