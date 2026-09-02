(in-package #:loom/feature/git)

(defun git-result-text (result)
  "Return captured Git output, falling back to diagnostics on failure."
  (let ((stdout (vcs-kit:process-result-stdout result))
        (stderr (vcs-kit:process-result-stderr result)))
    (if (and stdout (string/= stdout ""))
        stdout
        (or stderr ""))))
