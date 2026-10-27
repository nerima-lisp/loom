(in-package #:loom/feature/kill-ring)

(progn
  (defun %kill-ring-command-prefix-count ()
    (or *current-prefix-argument* 1))
  (defun %selected-kill-ring-buffer ()
    (loom/core/window-tree:window-buffer
     (loom/core/window-tree:window-tree-selected-window
      (editor-state-window-tree *editor-state*))))
  (defun %clear-last-yank ()
    (editor-state-clear-last-yank *editor-state*)))
