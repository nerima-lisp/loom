(in-package #:loom/feature/git)

(defun git-result-text (result)
  "Use standard error when Git produces no standard output, regardless of exit status."
  (let ((stdout (vcs-kit:process-result-stdout result))
        (stderr (vcs-kit:process-result-stderr result)))
    (if (and stdout (string/= stdout ""))
        stdout
        (or stderr ""))))
