(defpackage #:loom/feature/auto-save
  (:use #:cl #:loom #:loom/application)
  (:export
   #:*auto-save-interval*
   #:auto-save-path
   #:auto-save-eligible-p
   #:write-auto-save-file
   #:delete-auto-save-file
   #:auto-save-buffer-to-file
   #:auto-save-enabled-p
   #:auto-save-mode
   #:toggle-auto-save
   #:auto-save-current-buffer
   #:maybe-auto-save))
