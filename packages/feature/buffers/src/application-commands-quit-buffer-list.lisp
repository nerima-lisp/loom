(in-package #:loom/feature/buffers)

(defun quit-buffer-list ()
  "Return displayed and registered buffers with duplicates removed."
  (let ((displayed
         (mapcar (function loom/core/window-tree:window-buffer)
                 (loom/core/window-tree:window-tree-windows
                  (editor-state-window-tree *editor-state*))))
        (registered
         (copy-list (loom/feature/buffers:registered-buffers *editor-session*))))
    (remove-duplicates (append displayed registered) :test (function eq))))
