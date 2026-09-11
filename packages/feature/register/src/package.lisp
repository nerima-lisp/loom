(defpackage #:loom/feature/register
  (:use #:cl #:loom #:loom/application)
  (:export
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
   #:copy-to-register
   #:insert-register
   #:point-to-register
   #:jump-to-register))
