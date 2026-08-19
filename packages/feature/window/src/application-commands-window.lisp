;;;; packages/feature/window/src/application-commands-window.lisp
;;;;
;;;; Application layer: window-management and file-tree sidebar commands (see
;;;; application/commands-internal.lisp for the shared command-authoring
;;;; convention every commands-*.lisp file follows).
(in-package #:loom/feature/window)

(define-selected-tree-window-command split-window-below
  "Split the selected window horizontally, stacking top/bottom (C-x 2)."
  window-split
  :horizontal)

(define-selected-tree-window-command split-window-right
  "Split the selected window vertically, placing panes side by side (C-x 3)."
  window-split
  :vertical)

(defun other-window ()
  "Select the next window, cycling back to the first (C-x o)."
  (window-select-next (%selected-window-tree)))

(define-selected-tree-window-command delete-window
  "Delete the selected window, keeping at least one window (C-x 0)."
  window-delete)

(define-selected-tree-window-command delete-other-windows
  "Delete every window except the selected one (C-x 1)."
  window-delete-other-windows)

(defun switch-to-buffer ()
  "Prompt for a buffer name and display it in the selected window."
  (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                 :on-cancel (minibuffer-message minibuffer "Quit"))
      ((name "Switch to buffer: "
             :completion-function #'%buffer-name-completion-candidates))
    (let ((match (find name (%editor-buffers)
                       :key #'buffer-name
                       :test #'string=)))
      (if match
          (window-set-buffer (%selected-window) match)
          (minibuffer-message minibuffer (format nil "No such buffer: ~A" name))))))

(defun kill-buffer ()
  "Prompt for a buffer name and remove it from the session registry."
  (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                     :on-cancel (minibuffer-message minibuffer "Quit"))
      ((name "Kill buffer: "
             :completion-function #'%buffer-name-completion-candidates))
    (let ((buffer (find name (%editor-buffers)
                        :key #'buffer-name
                        :test #'string=)))
      (cond
        ((null buffer)
         (minibuffer-message minibuffer
                              (format nil "No such buffer: ~A" name)))
        ((buffer-modified-p buffer)
         (%prompt-kill-buffer minibuffer buffer))
        (t
         (%kill-buffer-now buffer))))))
