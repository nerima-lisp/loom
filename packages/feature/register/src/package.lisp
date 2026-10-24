(defpackage #:loom/feature/register
  (:use #:cl)
  (:import-from #:loom/core/buffer
                #:buffer-insert-string
                #:buffer-mark
                #:buffer-point-column
                #:buffer-point-line
                #:buffer-region-string
                #:buffer-set-point)
  (:import-from #:loom/core/editor-session
                #:*editor-state*
                #:editor-state-minibuffer
                #:editor-state-registers
                #:editor-state-window-tree)
  (:import-from #:loom/core/minibuffer
                #:minibuffer-message
                #:with-prompts)
  (:import-from #:loom/core/window-tree
                #:window-buffer
                #:window-tree-selected-window)
  (:export
   #:register-value
   #:register-value-p
   #:register-value-kind
   #:register-value-value
   #:register-bank
   #:register-bank-p
   #:make-register-bank
   #:register-bank-put-text
   #:register-bank-text
   #:register-bank-put-position
   #:register-bank-position
   #:copy-to-register
   #:insert-register
   #:point-to-register
   #:jump-to-register))
