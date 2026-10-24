(in-package #:loom/feature/window)

(defun split-window-below ()
  "Split the selected window horizontally, stacking top/bottom (C-x 2)."
  (let ((tree (editor-state-window-tree *editor-state*)))
    (window-split tree
                  (loom/core/window-tree:window-tree-selected-window tree)
                  :horizontal)))

(defun split-window-right ()
  "Split the selected window vertically, placing panes side by side (C-x 3)."
  (let ((tree (editor-state-window-tree *editor-state*)))
    (window-split tree
                  (loom/core/window-tree:window-tree-selected-window tree)
                  :vertical)))

(defun other-window ()
  "Select the next window, cycling back to the first (C-x o)."
  (window-select-next (editor-state-window-tree *editor-state*)))

(defun delete-window ()
  "Delete the selected window, keeping at least one window (C-x 0)."
  (let ((tree (editor-state-window-tree *editor-state*)))
    (window-delete tree
                   (loom/core/window-tree:window-tree-selected-window tree))))

(defun delete-other-windows ()
  "Delete every window except the selected one (C-x 1)."
  (let ((tree (editor-state-window-tree *editor-state*)))
    (window-delete-other-windows tree
                                 (loom/core/window-tree:window-tree-selected-window
                                  tree))))
