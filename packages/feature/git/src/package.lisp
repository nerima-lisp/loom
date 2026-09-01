(defpackage #:loom/feature/git
  (:documentation "Git status, diff, staging, and unstaging commands.")
  (:use #:cl
        #:loom
        #:loom/application
        #:loom/feature/project
        #:vcs-kit
        #:loom/feature/window)
  (:export
   #:run-git-status
   #:git-status
   #:run-git-diff
   #:git-diff
   #:git-diff-staged
   #:run-git-stage
   #:git-stage-file
   #:run-git-unstage
   #:git-unstage-file
   #:*git-command-timeout-seconds*))
