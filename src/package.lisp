(define-package-with-exports #:loom
  (#:cl #:loom/application #:loom/core/buffer)
  #.+loom-exports+)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (let ((buffer-package (find-package "LOOM/CORE/BUFFER"))
        (loom-package (find-package "LOOM")))
    (import (mapcar (lambda (name) (intern name buffer-package))
                    (list "%BUFFER-ORIGINAL"
                          "%BUFFER-ADD-BUFFER"
                          "%BUFFER-PIECES"
                          "%BUFFER-FULL-LENGTH"
                          "%BUFFER-NARROW-START-OFFSET"
                          "%BUFFER-NARROW-END-OFFSET"
                          "%BUFFER-NARROWED-P"
                          "%BUFFER-PATH"
                          "%ADVANCE-POSITION"
                          "%CLAMP-BUFFER-POINT-AND-MARK-TO-VISIBLE-REGION"
                          "%CLAMP-POSITION"
                          "%PIECES-TEXT"
                          "%POSITION-TO-OFFSET"
                          "%RAW-DELETE-REGION"
                          "%RAW-INSERT-AT"
                          "%SPLIT-NEWLINES"
                          "%TEXT-OFFSET-TO-POSITION-VALUES"
                          "%VALIDATE-NARROW-REGION-ORDER"))
             loom-package)))
