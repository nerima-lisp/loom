(defpackage #:loom/feature/format
  (:documentation "Buffer formatting commands and save hooks.")
  (:use #:cl
        #:loom/feature/shell)
  (:import-from #:loom/core/buffer
                #:buffer-delete-region
                #:buffer-insert-string
                #:buffer-line
                #:buffer-mark
                #:buffer-narrowed-p
                #:buffer-offset-position
                #:buffer-p
                #:buffer-path
                #:buffer-point-offset
                #:buffer-position-column
                #:buffer-position-line
                #:buffer-read-only-error
                #:buffer-read-only-p
                #:buffer-record-undo-boundary
                #:buffer-set-mark
                #:buffer-set-point
                #:buffer-text)
  (:import-from #:loom/core/editor-session
                #:*editor-state*
                #:editor-state-format-command
                #:editor-state-format-on-save-p
                #:editor-state-minibuffer
                #:editor-state-window-tree)
  (:import-from #:loom/core/minibuffer
                #:minibuffer-message
                #:with-prompts)
  (:export
   #:format-buffer-with-command
   #:format-current-buffer
   #:format-before-save
   #:format-on-save-mode
   #:set-format-command
   #:set-format-command-command))
