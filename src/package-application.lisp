;;;; src/package-application.lisp
;;;;
;;;; Shared application use-case primitives for the composition root.
(define-package-with-exports #:loom/application
  (#:cl)
  #.+loom/application-exports+)
