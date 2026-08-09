;;;; packages/feature/register/src/package.lisp
;;;;
;;;; Registers are a small feature with a domain bank and editor commands.
(defpackage #:loom/feature/register
  (:use #:cl #:loom #:loom/application)
  (:export
   ;; Domain API
   #:register-value
   #:register-value-p
   #:register-value-kind
   #:register-value-value
   #:register-bank
   #:register-bank-p
   #:make-register-bank
   #:register-bank-put-text
   #:register-bank-text
   #:register-bank-put-position
   #:register-bank-position
   ;; Application API
   #:copy-to-register
   #:insert-register
   #:point-to-register
   #:jump-to-register))
