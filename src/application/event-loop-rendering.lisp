;;;; src/application/event-loop-rendering.lisp
;;;;
;;;; Frame rendering and background refresh work for the main application
;;;; event loop.
(in-package #:loom)

(defun %render-event-loop-frame (stream)
  "Run background refresh work, compose the current frame, and present it."
  (loom/feature/terminal:poll-terminal-sessions *editor-state*)
  (let ((runtime (editor-state-concurrent-runtime *editor-state*)))
    (when runtime
      (loom/feature/file-tree:loom-concurrent-runtime-drain runtime)
      (loom/feature/file-tree:loom-concurrent-runtime-prefetch
       runtime
       (loom/feature/file-tree:file-tree-prefetch-paths
        (editor-state-file-tree *editor-state*)))))
  (let ((session (editor-state-lsp-session *editor-state*))
        (buffer (%selected-buffer)))
    (when (and session (buffer-path buffer))
      (loom/feature/lsp:lsp-session-refresh session buffer)))
  (compose-frame *editor-state*)
  (loom-renderer-present (editor-state-renderer *editor-state*)
                         :stream stream
                         :cursor (editor-cursor *editor-state*)))
