(in-package #:loom/feature/shell)

(defun %shell-directory-pathname (directory)
  (let* ((pathname (pathname (or directory (uiop:getcwd))))
         (directory-pathname
           (if (and (stringp directory)
                    (not (uiop:directory-pathname-p pathname)))
               (uiop:ensure-directory-pathname pathname)
               (if (pathname-name pathname)
                   (make-pathname :name nil :type nil :version nil
                                  :defaults pathname)
                   pathname))))
    (truename directory-pathname)))

(defparameter *shell-command-timeout-seconds* 30
  "Maximum time allowed for one shell command invocation.")

(defun run-shell-command (command &key directory
                                         (input nil input-supplied-p)
                                         (timeout-seconds
                                           *shell-command-timeout-seconds*))
  "Run COMMAND in DIRECTORY and capture both process streams.

COMMAND is intentionally passed through the platform shell, matching the
editor's pipe-command semantics.  A non-zero exit status is returned as data
in the result rather than signaled as a condition.

When INPUT-SUPPLIED-P is true, send INPUT to the process standard input and
close it after the string has been consumed.

TIMEOUT-SECONDS bounds the complete process invocation. A timed-out command
is represented as exit code 124 so callers can handle it as data."
  (check-type command string)
  (check-type timeout-seconds (real 0))
  (when input-supplied-p
    (check-type input string))
  (let ((working-directory (%shell-directory-pathname directory)))
    (labels ((execute (input-stream)
               (let* ((process-result
                        (process-kit:run-shell
                         command
                         :directory working-directory
                         :input input-stream
                         :output :capture
                         :error :capture
                         :timeout timeout-seconds
                         :on-timeout :return))
                      (timed-out-p
                        (process-kit:process-result-timed-out-p process-result)))
                 (make-shell-command-result
                  :command command
                  :directory (namestring working-directory)
                  :output (or (process-kit:process-result-stdout process-result) "")
                  :error-output
                  (if timed-out-p
                      (format nil "Command timed out after ~,3F seconds.~%"
                              timeout-seconds)
                      (or (process-kit:process-result-stderr process-result) ""))
                  :exit-code
                  (if timed-out-p
                      124
                      (process-kit:process-result-exit-code process-result))))))
      (if input-supplied-p
          (with-input-from-string (input-stream input)
            (execute input-stream))
          (execute nil)))))
