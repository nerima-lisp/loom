(in-package #:loom/test)

(describe
  "LSP diagnostics command state handling"
  (it "reports inactive and pathless diagnostic states"
    (%with-minibuffer-state (minibuffer "")
      (let* ((transport (make-instance '%fake-lsp-transport))
             (session (make-lsp-session :transport transport)))
        (unwind-protect
             (progn
               (lsp-stop)
               (expect (loom:minibuffer-message-string minibuffer)
                       :to-equal
                       "No LSP session.")
               (setf (editor-state-lsp-session *editor-state*) session)
               (loom/feature/lsp:lsp-diagnostics)
               (expect (loom:minibuffer-message-string minibuffer)
                       :to-equal
                       "LSP diagnostics need a file-backed buffer.")
               (lsp-stop)
               (expect (loom:minibuffer-message-string minibuffer)
                       :to-equal
                       "LSP stopped.")
               (loom/feature/lsp:lsp-diagnostics)
               (expect (loom:minibuffer-message-string minibuffer)
                       :to-equal
                       "No LSP session."))
          (lsp-session-stop session))))))
