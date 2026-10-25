(in-package #:loom/test)
(describe
  "buffer switching commands"
  (it
    "switch-to-buffer displays a buffer already shown in another window"
    (%with-minibuffer-state (minibuffer "selected"
                             (tree (editor-state-window-tree *editor-state*))
                             (other (make-buffer :name "other.txt" :initial-content "other")))
      (%register-test-buffer *editor-state* other)
      (window-set-buffer (window-split tree (window-tree-selected-window tree) :horizontal) other)
      (window-select-next tree)
      (loom/feature/buffers:switch-to-buffer)
      (%type-string minibuffer "other.t")
      (minibuffer-handle-key minibuffer (%special-key :tab))
      (expect (minibuffer-input-string minibuffer) :to-equal "other.txt")
      (minibuffer-handle-key minibuffer (%special-key :enter))
      (expect (buffer-name (window-buffer (window-tree-selected-window tree)))
              :to-equal "other.txt")))

  (it
    "switch-to-buffer reports an unknown buffer name"
    (%with-minibuffer-state (minibuffer "selected")
      (loom/feature/buffers:switch-to-buffer)
      (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer) "nope.txt")
      (expect (loom:minibuffer-message-string minibuffer) :to-equal "No such buffer: nope.txt")))

  (it
    "cancels switch-to-buffer through the minibuffer key protocol"
    (%with-minibuffer-state (minibuffer "selected")
      (loom/feature/buffers:switch-to-buffer)
      (minibuffer-handle-key minibuffer (%special-key :control-g))
      (expect (loom:minibuffer-message-string minibuffer) :to-equal "Quit"))))
