(in-package #:loom/feature/buffers)

(defun switch-to-buffer ()
  "Prompt for a buffer name and display it in the selected window."
  (with-prompts
   (minibuffer (editor-state-minibuffer *editor-state*)
               :on-cancel
               (minibuffer-message minibuffer "Quit"))
   ((name "Switch to buffer: "
          :completion-function
          #'%buffer-name-completion-candidates))
   (let ((match
          (find name
                (registered-buffers *editor-session*)
                :key
                #'buffer-name
                :test
                #'string=)))
     (if match
         (window-set-buffer
          (window-tree-selected-window
           (editor-state-window-tree *editor-state*))
          match)
         (minibuffer-message minibuffer (format nil "No such buffer: ~A" name))))))

(defun kill-buffer ()
  "Prompt for a buffer name and remove it from the session registry."
  (with-prompts
   (minibuffer (editor-state-minibuffer *editor-state*)
               :on-cancel
               (minibuffer-message minibuffer "Quit"))
   ((name "Kill buffer: "
          :completion-function
          #'%buffer-name-completion-candidates))
   (let ((buffer
          (find name
                (registered-buffers *editor-session*)
                :key
                #'buffer-name
                :test
                #'string=)))
     (cond
       ((null buffer)
        (minibuffer-message minibuffer (format nil "No such buffer: ~A" name)))
       ((buffer-modified-p buffer) (%prompt-kill-buffer minibuffer buffer))
       (t (%kill-buffer-now buffer))))))
