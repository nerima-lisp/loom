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
          (expect (window-height selected) :to-equal 24)))))

  (it
    "switch-to-buffer displays a buffer already shown in another window"
    (%with-minibuffer-state (minibuffer "selected"
                             (tree (editor-state-window-tree *editor-state*))
                             (other (make-buffer :name "other.txt" :initial-content "other")))
      (setf (editor-state-buffers *editor-state*)
            (cons other (editor-state-buffers *editor-state*)))
      (window-set-buffer (window-split tree (window-tree-selected-window tree) :horizontal) other)
      (window-select-next tree)
      (loom/feature/window:switch-to-buffer)
      (%type-string minibuffer "other.t")
      (minibuffer-handle-key minibuffer (%special-key :tab))
      (expect (minibuffer-input-string minibuffer) :to-equal "other.txt")
      (minibuffer-handle-key minibuffer (%special-key :enter))
      (expect (buffer-name (window-buffer (window-tree-selected-window tree)))
              :to-equal "other.txt")))

  (it
    "switch-to-buffer reports an unknown buffer name"
    (%with-minibuffer-state (minibuffer "selected")
      (loom/feature/window:switch-to-buffer)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "nope.txt")
      (expect (loom:minibuffer-message-string minibuffer) :to-equal "No such buffer: nope.txt")))

  (it
    "cancels switch-to-buffer through the minibuffer key protocol"
    (%with-minibuffer-state (minibuffer "selected")
      (loom/feature/window:switch-to-buffer)
      (minibuffer-handle-key minibuffer (%special-key :control-g))
      (expect (loom:minibuffer-message-string minibuffer) :to-equal "Quit"))))
