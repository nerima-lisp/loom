(in-package #:loom)

(defun %render-event-loop-frame (stream render-frame-function)
  "Refresh application state before presenting a frame through the root adapter."
  (loom/feature/file-tree:refresh-file-tree-runtime *editor-state*)
  (loom/feature/lsp:lsp-refresh-editor-state *editor-state*)
  (funcall render-frame-function stream))

