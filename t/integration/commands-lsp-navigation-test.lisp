;;;; t/integration/commands-lsp-navigation-test.lisp
(in-package #:loom/test)

(describe
  "LSP completion at point"
  (it
    "reports the missing session without sending a request"
    (let ((*editor-state* (%lsp-navigation-state)))
      (loom/feature/lsp:lsp-completion-at-point)
      (expect (minibuffer-message-string
               (editor-state-minibuffer *editor-state*))
              :to-equal "No LSP session for this buffer")))

  (it
    "reports the missing file path without sending a request"
    (%with-lsp-navigation (transport session buffer)
      (setf (loom::%buffer-path buffer) nil)
      (let ((before (length (%fake-sent-in-order transport))))
        (loom/feature/lsp:lsp-completion-at-point)
        (expect (minibuffer-message-string
                 (editor-state-minibuffer *editor-state*))
                :to-equal "No LSP session for this buffer")
        (expect (length (%fake-sent-in-order transport)) :to-equal before))))

  (it
    "says so and sends nothing when the server does not provide completion"
    (%with-lsp-navigation (transport session buffer :capabilities "{}")
      (let ((before (length (%fake-sent-in-order transport))))
        (loom/feature/lsp:lsp-completion-at-point)
        (expect (minibuffer-message-string
                 (editor-state-minibuffer *editor-state*))
                :to-equal "Server does not provide completion")
        (expect (length (%fake-sent-in-order transport)) :to-equal before)
        (expect (editor-state-completion *editor-state*) :to-be nil))))

  (it
    "sends textDocument/completion and shows the reply as a popup"
    (%with-lsp-navigation (transport session buffer)
      (buffer-set-point buffer 0 3)
      (loom/feature/lsp:lsp-completion-at-point)
      (expect (%lsp-last-request-method transport)
              :to-equal "textDocument/completion")
      (%fake-push-and-drain
       transport session
       (format nil
               "{\"jsonrpc\":\"2.0\",\"id\":~D,\"result\":[{\"label\":\"foobar\"},{\"label\":\"foobaz\"}]}"
               (%lsp-last-request-id transport)))
      (let ((completion (editor-state-completion *editor-state*)))
        (expect completion :to-be-truthy)
        (expect (mapcar #'editor-completion-item-label
                        (editor-completion-items completion))
                :to-equal '("foobar" "foobaz"))
        (expect (editor-completion-column completion) :to-equal 0))))

  (it
    "anchors the popup at the start of the symbol being completed"
    (%with-lsp-navigation (transport session buffer :content "(list foo")
      (buffer-set-point buffer 0 9)
      (loom/feature/lsp:lsp-completion-at-point)
      (%fake-push-and-drain
       transport session
       (format nil "{\"jsonrpc\":\"2.0\",\"id\":~D,\"result\":[{\"label\":\"foobar\"}]}"
               (%lsp-last-request-id transport)))
      (expect (editor-completion-column
               (editor-state-completion *editor-state*))
              :to-equal 6)))

  (it
    "reports an empty reply rather than opening an empty popup"
    (%with-lsp-navigation (transport session buffer)
      (loom/feature/lsp:lsp-completion-at-point)
      (%fake-push-and-drain
       transport session
       (format nil "{\"jsonrpc\":\"2.0\",\"id\":~D,\"result\":[]}"
               (%lsp-last-request-id transport)))
      (expect (editor-state-completion *editor-state*) :to-be nil)
      (expect (minibuffer-message-string
               (editor-state-minibuffer *editor-state*))
              :to-equal "No completions")))

  (it
    "reports a server error instead of leaving the request hanging"
    (%with-lsp-navigation (transport session buffer)
      (loom/feature/lsp:lsp-completion-at-point)
      (%fake-push-and-drain
       transport session
       (format nil
               "{\"jsonrpc\":\"2.0\",\"id\":~D,\"error\":{\"code\":-32603,\"message\":\"boom\"}}"
               (%lsp-last-request-id transport)))
      (expect (minibuffer-message-string
               (editor-state-minibuffer *editor-state*))
              :to-equal "Completion failed: boom")
      (expect (editor-state-completion *editor-state*) :to-be nil))))
