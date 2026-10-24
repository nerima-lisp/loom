(defpackage #:loom/feature/bookmark
  (:use #:cl)
  (:export #:editor-bookmark
           #:editor-bookmark-p
           #:make-editor-bookmark
           #:editor-bookmark-name
           #:editor-bookmark-buffer
           #:editor-bookmark-path
           #:editor-bookmark-buffer-name
           #:editor-bookmark-line
           #:editor-bookmark-column))
