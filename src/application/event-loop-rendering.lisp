(in-package #:loom)

(defun %render-event-loop-frame (stream)
  "Run background refresh work, compose the current frame, and present it."
  (loom/feature/terminal:poll-terminal-sessions *editor-state*)
  (let ((runtime (editor-state-concurrent-runtime *editor-state*)))
    (when runtime
      (loom/feature/file-tree:loom-concurrent-runtime-drain runtime)
      (loom/feature/file-tree:loom-concurrent-runtime-prefetch runtime
                                                               (loom/feature/file-tree:file-tree-prefetch-paths
                                                                (editor-state-file-tree
                                                                 *editor-state*)))))
  (let ((session (editor-state-lsp-session *editor-state*))
        (buffer
         (loom/core/window-tree:window-buffer
          (loom/core/window-tree:window-tree-selected-window
           (editor-state-window-tree *editor-state*)))))
    (when (and session (buffer-path buffer))
      (loom/feature/lsp:lsp-session-refresh session buffer)))
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
