(defpackage #:loom/feature/format
  (:use #:cl
        #:loom
        #:loom/application
        #:loom/feature/shell)
  (:export
   #:format-buffer-with-command
   #:format-current-buffer
   #:format-before-save
   #:format-on-save-mode
   #:set-format-command
   #:set-format-command-command))
