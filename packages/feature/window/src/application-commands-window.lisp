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

(defun switch-to-buffer ()
  "Prompt for a buffer name and display it in the selected window."
  (loom/core/minibuffer:with-prompts
   (minibuffer (editor-state-minibuffer *editor-state*)
               :on-cancel
               (minibuffer-message minibuffer "Quit"))
   ((name "Switch to buffer: "
          :completion-function
          #'%buffer-name-completion-candidates))
   (let ((match
          (find name
                (editor-state-buffers *editor-state*)
                :key
                #'buffer-name
                :test
                #'string=)))
     (if match
         (window-set-buffer
          (loom/core/window-tree:window-tree-selected-window
           (editor-state-window-tree *editor-state*))
          match)
         (minibuffer-message minibuffer (format nil "No such buffer: ~A" name))))))

(defun kill-buffer ()
  "Prompt for a buffer name and remove it from the session registry."
  (loom/core/minibuffer:with-prompts
   (minibuffer (editor-state-minibuffer *editor-state*)
               :on-cancel
               (minibuffer-message minibuffer "Quit"))
   ((name "Kill buffer: "
          :completion-function
          #'%buffer-name-completion-candidates))
   (let ((buffer
          (find name
                (editor-state-buffers *editor-state*)
                :key
                #'buffer-name
                :test
                #'string=)))
     (cond
       ((null buffer)
        (minibuffer-message minibuffer (format nil "No such buffer: ~A" name)))
       ((buffer-modified-p buffer) (%prompt-kill-buffer minibuffer buffer))
       (t (%kill-buffer-now buffer))))))
