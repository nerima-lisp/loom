(in-package #:loom/test)
(describe
  "window commands"
  (it
    "split-window-below adds a second window stacked below the first"
    (let ((*editor-state* (%fresh-editor-state "hi")))
      (let ((tree (editor-state-window-tree *editor-state*)))
        (expect (length (window-tree-windows tree)) :to-equal 1)
        (loom/feature/window:split-window-below)
        (expect (length (window-tree-windows tree)) :to-equal 2))))

  (it
    "split-window-right adds a second window beside the first"
    (let ((*editor-state* (%fresh-editor-state "hi")))
      (let ((tree (editor-state-window-tree *editor-state*)))
        (loom/feature/window:split-window-right)
        (expect (length (window-tree-windows tree)) :to-equal 2))))

  (it
    "other-window cycles back to the original window after a split"
    (let ((*editor-state* (%fresh-editor-state "hi")))
      (let* ((tree (editor-state-window-tree *editor-state*))
             (original (window-tree-selected-window tree)))
        (loom/feature/window:split-window-below)
        (expect (eq (window-tree-selected-window tree) original) :to-be nil)
        (loom/feature/window:other-window)
        (expect (window-tree-selected-window tree) :to-be original))))

  (it
    "delete-window removes the selected split and restores the full layout"
    (let ((*editor-state* (%fresh-editor-state "hi")))
      (let* ((tree (editor-state-window-tree *editor-state*))
             (original (window-tree-selected-window tree)))
        (loom/feature/window:split-window-below)
        (loom/feature/window:delete-window)
        (expect (window-tree-windows tree) :to-have-length 1)
        (expect (window-tree-selected-window tree) :to-be original)
        (expect (window-width original) :to-equal 80)
        (expect (window-height original) :to-equal 24))))

  (it
    "delete-other-windows keeps the selected pane and restores the full layout"
    (let ((*editor-state* (%fresh-editor-state "hi")))
      (let* ((tree (editor-state-window-tree *editor-state*)))
        (loom/feature/window:split-window-right)
        (loom/feature/window:split-window-below)
        (let ((selected (window-tree-selected-window tree)))
          (loom/feature/window:delete-other-windows)
          (expect (window-tree-windows tree) :to-have-length 1)
          (expect (window-tree-selected-window tree) :to-be selected)
          (expect (window-x selected) :to-equal 0)
          (expect (window-y selected) :to-equal 0)
          (expect (window-width selected) :to-equal 80)
          (expect (window-height selected) :to-equal 24))))))
