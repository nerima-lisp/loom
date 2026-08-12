;;;; src/package.lisp
;;;;
;;;; Public kernel package for loom. Export lists live in package-exports.lisp
;;;; so the package definition stays short and the groups can evolve without
;;;; stretching this file again.
(define-package-with-exports #:loom
  (#:cl #:loom/application)
  #.+loom-exports+)
