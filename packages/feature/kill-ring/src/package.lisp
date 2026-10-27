(defpackage #:loom/feature/kill-ring
            (:use #:cl)
            (:import-from #:loom/core/buffer
                          #:buffer-active-region-span
                          #:buffer-deactivate-mark
                          #:buffer-delete-region
                          #:buffer-insert-string
                          #:buffer-line
                          #:buffer-line-count
                          #:buffer-narrow-start-offset
                          #:buffer-offset-position
                          #:buffer-point-column
                          #:buffer-point-line
                          #:buffer-point-offset
                          #:buffer-position-column
                          #:buffer-position-line
                          #:buffer-region-string
                          #:buffer-set-point
                          #:buffer-span-end
                          #:buffer-span-start
                          #:buffer-visible-text)
            (:import-from #:loom/core/command #:*current-prefix-argument*)
            (:import-from #:loom/core/editor-session
                          #:*editor-state*
                          #:editor-state-clear-last-yank
                          #:editor-state-kill-ring
                          #:editor-state-last-command-kill-p
                          #:editor-state-last-yank-buffer
                          #:editor-state-last-yank-end-offset
                          #:editor-state-last-yank-ranges
                          #:editor-state-last-yank-repeat-count
                          #:editor-state-last-yank-ring-index
                          #:editor-state-last-yank-start-offset
                          #:editor-state-minibuffer
                          #:editor-state-window-tree)
            (:import-from #:loom/core/minibuffer #:minibuffer-message)
            (:export #:backward-kill-word
                     #:kill-line
                     #:kill-region
                     #:kill-ring-save
                     #:kill-word
                     #:yank
                     #:yank-pop))
