(in-package #:loom/test)

(describe
  "LSP session diagnostics"
  (it "covers document synchronization no-ops and changes"
    (%with-started-fake-lsp-session
        ((transport session))
      (let* ((pathless (make-buffer :name "scratch" :initial-content ""))
             (buffer (make-buffer :name "main.lisp"
                                  :path "/tmp/main.lisp"
                                  :initial-content "(+ 1 2)")))
        (lsp-session-sync-buffer session pathless)
        (expect (length (%fake-sent-in-order transport)) :to-equal 1)
        (lsp-session-sync-buffer session pathless)
        (expect (length (%fake-sent-in-order transport)) :to-equal 1)
        (%fake-push-and-drain
         transport
         session
         "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{}}")
        (lsp-session-sync-buffer session pathless)
        (expect (length (%fake-sent-in-order transport)) :to-equal 2)
        (lsp-session-sync-buffer session buffer)
        (expect (length (%fake-sent-in-order transport)) :to-equal 3)
        (lsp-session-sync-buffer session buffer)
        (expect (length (%fake-sent-in-order transport)) :to-equal 3)
        (buffer-insert-string buffer "!")
        (lsp-session-sync-buffer session buffer)
        (let* ((messages (%fake-sent-in-order transport))
               (change (%parse-lsp-json (fourth messages)))
               (params (gethash "params" change))
               (document (gethash "textDocument" params)))
          (expect (gethash "method" change) :to-equal "textDocument/didChange")
          (expect (gethash "version" document) :to-equal 2))
        (signals error (lsp-session-sync-buffer session :not-a-buffer)))))

  (it "validates protocol messages and diagnostic paths"
    (%with-started-fake-lsp-session ((transport session))
      (flet ((expect-error (json)
               (%expect-session-error-after-message transport session json)))
        (expect-error "[]")
        (expect-error
         "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/publishDiagnostics\"}")
        (expect-error
         "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/publishDiagnostics\",\"params\":[]}")
        (expect-error
         "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/publishDiagnostics\",\"params\":{\"uri\":1,\"diagnostics\":[]}}")
        (expect-error
         "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/publishDiagnostics\",\"params\":{\"uri\":\"file:///tmp/main.lisp\",\"diagnostics\":[[]]}}")
        (expect-error
         "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/publishDiagnostics\",\"params\":{\"uri\":\"file:///tmp/main.lisp\",\"diagnostics\":[{}]}}")
        (expect-error
         "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/publishDiagnostics\",\"params\":{\"uri\":\"file:///tmp/main.lisp\",\"diagnostics\":[{\"range\":[],\"message\":\"bad\"}]}}")
        (expect-error
         "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/publishDiagnostics\",\"params\":{\"uri\":\"file:///tmp/main.lisp\",\"diagnostics\":[{\"range\":{\"start\":[],\"end\":{\"line\":0,\"character\":0}},\"message\":\"bad\"}]}}")
        (expect-error
         "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/publishDiagnostics\",\"params\":{\"uri\":\"file:///tmp/main.lisp\",\"diagnostics\":[{\"range\":{\"start\":{\"line\":\"zero\",\"character\":0},\"end\":{\"line\":0,\"character\":0}},\"message\":\"bad\"}]}}"))
      (setf (lsp-session-last-error session) nil)
      (%expect-ignored-message
          (transport session)
          "{\"jsonrpc\":\"2.0\",\"method\":\"$/progress\"}")
      (%expect-ignored-message
          (transport session)
          "{\"jsonrpc\":\"2.0\",\"id\":99,\"result\":{}}"
        (expect (loom/feature/lsp::lsp-session-pending-initialize-id session)
                :to-equal 1))
      (%fake-push-publish-diagnostics
       transport
       "/tmp/main.lisp"
       "[{\"range\":{\"start\":{\"line\":0,\"character\":1},\"end\":{\"line\":0,\"character\":2}},\"message\":\"bad\",\"severity\":null,\"source\":null,\"code\":7}]")
      (lsp-session-drain session)
      (let ((diagnostic (first (lsp-session-diagnostics
                                session
                                "/tmp/main.lisp"))))
        (expect (lsp-diagnostic-severity diagnostic) :to-be nil)
        (expect (lsp-diagnostic-source diagnostic) :to-be nil)
        (expect (lsp-diagnostic-code diagnostic) :to-equal 7))
      (expect (lsp-session-diagnostics session #P"/tmp/main.lisp")
              :to-have-length
              1)
      (expect (lsp-session-diagnostics session nil) :to-be nil)))

  (it "ignores invalid optional diagnostic field types"
    (%with-initialized-fake-lsp-session ((transport session))
      (%fake-push-publish-diagnostics
       transport
       "/tmp/main.lisp"
       "[{\"range\":{\"start\":{\"line\":0,\"character\":0},\"end\":{\"line\":0,\"character\":1}},\"message\":\"bad\",\"severity\":\"error\",\"source\":42,\"code\":{}}]")
      (lsp-session-drain session)
      (let ((diagnostic (first (lsp-session-diagnostics session "/tmp/main.lisp"))))
        (expect (lsp-diagnostic-message diagnostic) :to-equal "bad")
        (expect (lsp-diagnostic-severity diagnostic) :to-be nil)
        (expect (lsp-diagnostic-source diagnostic) :to-be nil)
        (expect (hash-table-p (lsp-diagnostic-code diagnostic)) :to-be-truthy))))

  (it "synchronizes a buffer and stores published diagnostics"
    (%with-initialized-fake-lsp-session ((transport session))
      (let ((buffer (make-buffer :name "main.lisp"
                                 :path "/tmp/main.lisp"
                                 :initial-content "(+ 1 2)")))
        (lsp-session-sync-buffer session buffer)
        (let* ((open (%fake-sent-message transport 2))
               (text-document
                 (gethash "params" open)))
          (expect (gethash "method" open)
                  :to-equal "textDocument/didOpen")
          (expect (gethash "textDocument" text-document)
                  :to-be-truthy))
        (%fake-push-publish-diagnostics
         transport
         "/tmp/main.lisp"
         "[{\"range\":{\"start\":{\"line\":0,\"character\":1},\"end\":{\"line\":0,\"character\":2}},\"message\":\"bad\",\"severity\":1,\"source\":\"fake\"}]")
        (lsp-session-drain session)
        (let ((diagnostics (lsp-session-diagnostics session buffer)))
          (expect diagnostics :to-have-length 1)
          (expect (lsp-diagnostic-message (first diagnostics)) :to-equal "bad")
          (expect (lsp-diagnostic-severity (first diagnostics)) :to-equal 1)
          (expect (lsp-diagnostic-source (first diagnostics)) :to-equal "fake"))))))
