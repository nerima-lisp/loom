(in-package #:loom/test)

(describe
  "LSP diagnostics command formatting"
  (it "reports transport errors and renders optional diagnostic fields"
    (let* ((transport (make-instance '%fake-lsp-transport))
           (session (make-lsp-session :transport transport))
           (buffer (make-buffer :name "main.lisp"
                                :path "/tmp/main.lisp"
                                :initial-content "(+ 1 2)"))
           (state
             (make-editor-state
              :window-tree (make-window-tree buffer 80 24)
              :minibuffer (make-minibuffer)
              :keymap (make-keymap)
              :file-tree nil
              :renderer nil
              :buffers (list buffer)
              :kill-ring nil)))
      (unwind-protect
           (let ((*editor-state* state))
             (setf (editor-state-lsp-session state) session
                   (lsp-session-last-error session) "broken transport")
             (lsp-diagnostics)
             (expect (loom:minibuffer-message-string
                      (editor-state-minibuffer state))
                     :to-equal
                     "LSP error: broken transport")
             (setf (lsp-session-last-error session) nil)
             (expect (loom/feature/lsp::%lsp-error-message session)
                     :to-equal
                     "unknown LSP error")
             (expect (loom/feature/lsp::%lsp-diagnostics-text
                      buffer
                      (list
                       (make-lsp-diagnostic
                        (make-lsp-range
                         (make-lsp-position 0 0)
                         (make-lsp-position 0 1))
                        "plain diagnostic")))
                     :to-equal
                     (format nil
                             "Diagnostics for main.lisp~%1:1 plain diagnostic~%")))
        (lsp-session-stop session)))))
