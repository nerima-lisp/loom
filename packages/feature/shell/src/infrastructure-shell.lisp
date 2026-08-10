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

(defun run-shell-command (command &key directory (input nil input-supplied-p))
  "Run COMMAND in DIRECTORY and capture both process streams.

COMMAND is intentionally passed through the platform shell, matching the
editor's pipe-command semantics.  A non-zero exit status is returned as data
in the result rather than signaled as a condition.

When INPUT-SUPPLIED-P is true, send INPUT to the process standard input and
close it after the string has been consumed."
  (check-type command string)
  (when input-supplied-p
    (check-type input string))
  (let ((working-directory (%shell-directory-pathname directory)))
    (labels ((execute (input-stream)
               (multiple-value-bind (output error-output exit-code)
                   (uiop:run-program command
                                     :shell t
                                     :directory working-directory
                                     :input input-stream
                                     :output :string
                                     :error-output :string
                                     :ignore-error-status t)
                 (make-shell-command-result
                  :command command
                  :directory (namestring working-directory)
                  :output (or output "")
                  :error-output (or error-output "")
                  :exit-code exit-code))))
      (if input-supplied-p
          (with-input-from-string (input-stream input)
            (execute input-stream))
          (execute nil)))))
