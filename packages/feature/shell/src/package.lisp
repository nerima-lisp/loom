(defpackage #:loom/feature/shell
  (:use #:cl
        #:loom
        #:loom/application
        #:loom/feature/window)
  (:export
   #:shell-command-result
   #:shell-command-result-p
   #:make-shell-command-result
   #:shell-command-result-command
   #:shell-command-result-directory
   #:shell-command-result-output
   #:shell-command-result-error-output
   #:shell-command-result-exit-code
   #:shell-command-result-success-p
   #:shell-command-result-text
   #:run-shell-command
   #:pipe-command))
