(in-package #:loom/feature/git)

(defun git-status ()
  "Display concise Git status for the current project."
  (handler-case
      (let* ((directory (%git-status-directory))
             (result (run-git-status :directory directory))
             (buffer (%replace-git-result-buffer
                      (%git-result-buffer *git-status-buffer-name*)
                      (shell-command-result-text result))))
        (window-set-buffer (%selected-window) buffer)
        (minibuffer-message
         (editor-state-minibuffer *editor-state*)
         (if (shell-command-result-success-p result)
             "Git status refreshed"
             (format nil "Git status exited with status ~D"
                     (shell-command-result-exit-code result))))
        result)
    (error (condition)
      (minibuffer-message
       (editor-state-minibuffer *editor-state*)
       (format nil "Git status error: ~A" condition))
      nil)))

(defun %display-git-diff (staged)
  "Display the working-tree or staged diff in a read-only result buffer."
  (handler-case
      (let* ((directory (%git-status-directory))
             (result (run-git-diff :directory directory :staged staged))
             (buffer (%replace-git-result-buffer
                      (%git-result-buffer *git-diff-buffer-name*)
                      (shell-command-result-text result))))
        (window-set-buffer (%selected-window) buffer)
        (minibuffer-message
         (editor-state-minibuffer *editor-state*)
         (if (shell-command-result-success-p result)
             (if staged
                 "Git staged diff refreshed"
                 "Git diff refreshed")
             (format nil "Git diff exited with status ~D"
                     (shell-command-result-exit-code result))))
        result)
    (error (condition)
      (minibuffer-message
       (editor-state-minibuffer *editor-state*)
       (format nil "Git diff error: ~A" condition))
      nil)))

(defun git-diff ()
  "Display the current working-tree diff for the current project."
  (%display-git-diff nil))

(defun git-diff-staged ()
  "Display the staged index diff for the current project."
  (%display-git-diff t))

(defun git-stage-file ()
  "Prompt for a repository path and stage it in Git's index."
  (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                 :on-cancel (minibuffer-message minibuffer "Quit"))
      ((path "Git stage file: "))
    (%git-file-operation :stage path minibuffer)))

(defun git-unstage-file ()
  "Prompt for a repository path and remove it from Git's index."
  (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                 :on-cancel (minibuffer-message minibuffer "Quit"))
      ((path "Git unstage file: "))
    (%git-file-operation :unstage path minibuffer)))
