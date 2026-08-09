;;;; packages/feature/syntax-highlighting/src/package.lisp
;;;;
;;;; Syntax highlighting depends on the mode feature for language metadata.
(defpackage #:loom/feature/syntax-highlighting
  (:use #:cl #:loom #:loom/feature/mode)
  (:export
   #:syntax-token
   #:syntax-token-p
   #:syntax-token-kind
   #:syntax-token-text
   #:syntax-highlight-line
   #:syntax-highlight-line-for-mode))
