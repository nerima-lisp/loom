;;;; src/package-user.lisp
;;;;
;;;; The user package is defined after every public feature package exists.
(defpackage #:loom-user
  (:use #:cl #:loom #:loom/feature/lsp #:loom/feature/user-init))
