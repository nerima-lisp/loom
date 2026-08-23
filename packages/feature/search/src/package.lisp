;;;; packages/feature/search/src/package.lisp
;;;;
;;;; Buffer search primitives and their editor commands are one feature API.
(defpackage #:loom/feature/search
  (:use #:cl #:loom #:loom/application)
  (:export
   ;; Domain API
   #:buffer-search-forward
   #:buffer-search-backward
   #:buffer-search-spans
   #:make-isearch-session
   #:isearch-session-buffer
   #:isearch-session-origin-offset
   #:isearch-session-direction
   #:isearch-session-pattern
   #:isearch-session-match
   #:isearch-session-matches
   #:isearch-session-failed-p
   #:isearch-apply-pattern
   #:isearch-repeat
   ;; Application API
   #:replace-string
   #:search-forward
   #:search-backward
   #:isearch-forward
   #:isearch-backward))
