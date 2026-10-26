(in-package #:loom)

(defun %render-event-loop-frame (stream)
  "Run background refresh work, compose the current frame, and present it."
  (loom/feature/file-tree:refresh-file-tree-runtime *editor-state*)
  (loom/feature/lsp:lsp-refresh-editor-state *editor-state*)
  (compose-frame *editor-state*)
  (loom-renderer-present (editor-state-renderer *editor-state*)
                         :stream
                         stream
                         :cursor
                         (editor-cursor *editor-state*)))

(defun %apply-render-session-hooks (session snapshot glyph-layout-function)
  "Apply immutable render-hook operations to SNAPSHOT for direct callers."
  (let ((operations
         (loop for result in (loom/core/editor-session:run-session-hooks :render
                                                                         session
                                                                         snapshot)
               append result)))
    (loom/core/editor-session:apply-render-operations snapshot
                                                      operations
                                                      glyph-layout-function)))
