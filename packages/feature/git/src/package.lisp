(defpackage #:loom/feature/git
  (:use #:cl
        #:loom
        #:loom/application
        #:loom/feature/project
        #:loom/feature/shell
        #:loom/feature/window)
  (:export
   #:git-status-command
   #:run-git-status
   #:git-status
   #:git-diff-command
   #:run-git-diff
   #:git-diff
   #:git-diff-staged
   #:git-stage-command
   #:run-git-stage
   #:git-stage-file
   #:git-unstage-command
   #:run-git-unstage
   #:git-unstage-file))
