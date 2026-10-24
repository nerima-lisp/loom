(defpackage #:loom/feature/evaluation
  (:use #:cl #:loom/core/window-tree)
  (:import-from #:loom/core/buffer
                #:buffer-insert-string
                #:buffer-line
                #:buffer-line-count
                #:buffer-mark-saved
                #:buffer-name
                #:buffer-set-point
                #:buffer-text
                #:make-buffer)
  (:import-from #:loom/core/editor-session
                #:*editor-session*
                #:*editor-state*
                #:editor-state-minibuffer
                #:editor-state-window-tree)
  (:import-from #:loom/core/minibuffer
                #:minibuffer-message
                #:with-prompts)
  (:import-from #:loom/feature/buffers
                #:registered-buffers
                #:register-buffer)
  (:export #:evaluation-result
           #:make-evaluation-result
           #:evaluation-result-p
           #:evaluation-result-form-count
           #:evaluation-result-value-lines
           #:evaluation-result-output
           #:evaluation-result-error-output
           #:evaluation-result-error-message
           #:evaluation-result-success-p
           #:evaluation-result-text
           #:evaluate-lisp-source
           #:eval-expression
           #:eval-buffer
           #:register-evaluation-package-provider))
