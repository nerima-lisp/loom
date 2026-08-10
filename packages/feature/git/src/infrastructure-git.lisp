(in-package #:loom/feature/git)

(defun run-git-status (&key directory)
  "Run Git status in DIRECTORY and return its captured process result."
  (run-shell-command (git-status-command) :directory directory))

(defun run-git-diff (&key directory staged)
  "Run Git diff in DIRECTORY and return its captured process result."
  (run-shell-command (git-diff-command :staged staged)
                     :directory directory))

(defun run-git-stage (path &key directory)
  "Stage PATH in DIRECTORY and return its captured process result."
  (run-shell-command (git-stage-command path) :directory directory))

(defun run-git-unstage (path &key directory)
  "Remove PATH from the index in DIRECTORY and return its captured process
result."
  (run-shell-command (git-unstage-command path) :directory directory))
