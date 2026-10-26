(defpackage #:loom/core/minibuffer
  (:use #:cl)
  (:export
   #:minibuffer
   #:minibuffer-p
   #:make-minibuffer
   #:minibuffer-active-p
   #:minibuffer-prompt-string
   #:minibuffer-input-string
   #:minibuffer-input-point
   #:minibuffer-completion-candidates
   #:minibuffer-message-string
   #:minibuffer-activate
   #:minibuffer-set-prompt
   #:minibuffer-message
   #:register-message-sink
   #:minibuffer-history-entries
   #:minibuffer-set-history-entries
   #:minibuffer-complete
   #:minibuffer-handle-key
   #:with-prompts))
