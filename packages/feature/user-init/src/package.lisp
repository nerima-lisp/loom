;;;; packages/feature/user-init/src/package.lisp
;;;;
;;;; User configuration is an application boundary over the command registry.
(defpackage #:loom/feature/user-init
  (:use #:cl #:loom #:loom/application)
  (:export
   #:define-command
   #:bind-key
   #:load-user-init))
