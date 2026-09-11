(defpackage #:loom/feature/search
  (:use #:cl #:loom #:loom/application)
  (:export
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
   #:replace-string
   #:search-forward
   #:search-backward
   #:isearch-forward
   #:isearch-backward))
