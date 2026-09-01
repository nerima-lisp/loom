(in-package #:loom/feature/git)

(defun git-status ()
  "Display concise Git status for the current project."
  (%display-git-result
   *git-status-buffer-name*
   (lambda () (run-git-status :directory (%git-status-directory)))
   "Git status refreshed"
   "status"))

(defun %display-git-diff (staged)
  "Display the working-tree or staged diff in a read-only result buffer."
  (%display-git-result
   *git-diff-buffer-name*
   (lambda () (run-git-diff :directory (%git-status-directory) :staged staged))
   (if staged "Git staged diff refreshed" "Git diff refreshed")
   "diff"))

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
