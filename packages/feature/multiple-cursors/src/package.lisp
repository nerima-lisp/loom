;;;; packages/feature/multiple-cursors/src/package.lisp
;;;;
;;;; Multiple-cursor state and commands are isolated from the input and
;;;; presentation layers.  The composition root only needs the public
;;;; application protocol exported here.
(defpackage #:loom/feature/multiple-cursors
  (:use #:cl #:loom #:loom/application)
  (:export
   ;; Domain API
   #:multiple-cursor-set
   #:multiple-cursor-set-p
   #:make-multiple-cursor-set
   #:multiple-cursor-set-buffer
   #:multiple-cursor-set-offsets
   #:multiple-cursor-set-primary-offset
   ;; Application API
   #:multiple-cursors-active-p
   #:multiple-cursors-reset
   #:multiple-cursor-offsets-for-buffer
   #:multiple-cursors-preserving-command-p
   #:multiple-cursors-add-next-line
   #:multiple-cursors-edit-lines
   #:multiple-cursors-clear
   #:multiple-cursors-apply-insert
   #:multiple-cursors-apply-delete
   #:multiple-cursors-update-after-yank-pop))
