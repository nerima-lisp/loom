(in-package #:loom/feature/git)

(defun git-status-command ()
  "Return the concise branch-aware Git status command."
  "git status --short --branch")

(defun git-diff-command (&key staged)
  "Return the Git diff command for the working tree or index."
  (if staged
      "git diff --cached"
      "git diff"))

(defun %git-shell-quote (argument)
  "Return ARGUMENT quoted as one POSIX shell word.

Git's command runner accepts a shell command string, so paths must be quoted
before they cross that boundary.  A single quote inside a single-quoted word
is represented by closing the word, emitting an escaped quote, and opening
the word again."
  (check-type argument string)
  (with-output-to-string (stream)
    (write-char #\' stream)
    (loop for character across argument
          do (if (char= character #\')
                 (progn
                   (write-char #\' stream)
                   (write-char #\\ stream)
                   (write-char #\' stream)
                   (write-char #\' stream))
                 (write-char character stream)))
    (write-char #\' stream)))

(defun git-stage-command (path)
  "Return the Git command that stages PATH."
  (format nil "git add -- ~A" (%git-shell-quote path)))

(defun git-unstage-command (path)
  "Return the Git command that removes PATH from the index."
  (format nil "git restore --staged -- ~A" (%git-shell-quote path)))
