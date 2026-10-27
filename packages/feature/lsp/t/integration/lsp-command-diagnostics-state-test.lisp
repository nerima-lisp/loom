(in-package #:loom/test)

(describe
  "LSP diagnostics command state handling"
  (it "ignores a stale legacy session for a pathless buffer"
    (%with-lsp-minibuffer-state (minibuffer "")
      (let* ((transport (make-instance '%fake-lsp-transport))
             (session (make-lsp-session :transport transport)))
        (unwind-protect
             (progn
               (lsp-stop)
               (expect (loom:minibuffer-message-string minibuffer)
                       :to-equal
                       "No LSP session.")
               (progn
                 (setf (editor-state-lsp-session *editor-state*) session)
                 (expect
                  (loom/feature/lsp:lsp-session-for-buffer
                   (loom/core/editor-session:editor-state-session
                    *editor-state*)
                   (%selected-test-buffer))
                  :to-be nil))
               (loom/feature/lsp:lsp-diagnostics)
               (expect (loom:minibuffer-message-string minibuffer)
                       :to-equal
                       "No LSP session.")
               (lsp-stop)
               (expect (loom:minibuffer-message-string minibuffer)
                       :to-equal
                       "No LSP session.")
               (loom/feature/lsp:lsp-diagnostics)
               (expect (loom:minibuffer-message-string minibuffer)
                       :to-equal
                       "No LSP session."))
          (lsp-session-stop session))))))
