(defpackage #:loom/feature/search
  (:use #:cl)
  (:import-from #:loom/core/buffer
                #:buffer-delete-region
                #:buffer-insert-string
                #:buffer-narrow-start-offset
                #:buffer-offset
                #:buffer-offset-position
                #:buffer-point-offset
                #:buffer-position-column
                #:buffer-position-line
                #:buffer-set-point
                #:buffer-span-end
                #:buffer-span-start
                #:buffer-visible-text
                #:make-buffer-span)
  (:import-from #:loom/core/editor-session
                #:*editor-state*
                #:editor-state-minibuffer
                #:editor-state-window-tree)
  (:import-from #:loom/core/minibuffer
                #:minibuffer-message
                #:with-prompts)
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
   #:isearch-backward
   #:result-item
   #:result-item-p
   #:make-result-item
   #:result-item-file-path
   #:result-item-line
   #:result-item-column
   #:result-item-display-text
   #:publish-result-list
   #:next-error
   #:previous-error
   #:search-result-visit))
