(in-package #:loom/feature/shell)

(defstruct (shell-command-result
            (:constructor make-shell-command-result
                (&key command directory (output "") (error-output "")
                      (exit-code 0)))
            (:copier nil))
  "The captured result of one shell command invocation.

COMMAND is the command string passed to the shell.  DIRECTORY is the
canonical directory in which it ran.  OUTPUT contains captured stdout.
ERROR-OUTPUT contains captured stderr unless the command timed out; on
timeout, it contains a timeout diagnostic instead."
  command
  directory
  output
  error-output
  exit-code)

(defun shell-command-result-success-p (result)
  "Return true when RESULT exited successfully."
  (zerop (shell-command-result-exit-code result)))

(defun %write-shell-result-stream (stream label text)
  (when (string/= text "")
    (format stream "~A:~%" label)
    (write-string text stream)
    (unless (char= (char text (1- (length text))) #\Newline)
      (terpri stream))))

(defun shell-command-result-text (result)
  "Render RESULT as readable text for a command-result buffer."
  (with-output-to-string (stream)
    (format stream "$ ~A~%" (shell-command-result-command result))
    (format stream "Directory: ~A~%"
            (shell-command-result-directory result))
    (%write-shell-result-stream
     stream "Output" (shell-command-result-output result))
    (%write-shell-result-stream
     stream "Error output" (shell-command-result-error-output result))
    (format stream "Exit code: ~D~%"
            (shell-command-result-exit-code result))))
