(in-package #:loom/test)

(describe
  "LSP session shutdown"
  (it "does not receive messages after the session is closed"
    (%with-started-fake-lsp-session ((transport session))
      (setf (loom/feature/lsp::lsp-session-closed-p session) t)
      (expect (lsp-session-drain session) :to-be session)
      (expect (%fake-sent-in-order transport) :to-have-length 1)))

  (it "stops with shutdown followed by exit after an acknowledge"
    (%with-started-fake-lsp-session ((transport session))
      (%fake-push-initialize-response
       transport
       "{\"capabilities\":{\"hoverProvider\":true},\"serverInfo\":{\"name\":\"fake\",\"version\":\"1\"}}")
      (lsp-session-drain session)
      (%fake-push-incoming
       transport
       "{\"jsonrpc\":\"2.0\",\"id\":2,\"result\":null}")
      (lsp-session-stop session)
      (expect (%fake-closed-p transport) :to-be-truthy)
      (let* ((messages (%fake-sent-in-order transport))
             (shutdown (%fake-sent-message transport 2))
             (exit (%fake-sent-message transport 3)))
        (expect messages :to-have-length 4)
        (expect (gethash "method" shutdown)
                :to-equal "shutdown")
        (expect (gethash "id" shutdown)
                :to-equal 2)
        (expect (gethash "method" exit)
                :to-equal "exit"))))

  (it "falls back to exit when shutdown is not acknowledged"
    (%with-initialized-fake-lsp-session ((transport session))
      (lsp-session-stop session :timeout 0)
      (let* ((messages (%fake-sent-in-order transport))
             (shutdown (%fake-sent-message transport 2))
             (exit (%fake-sent-message transport 3)))
        (expect messages :to-have-length 4)
        (expect (gethash "method" shutdown)
                :to-equal "shutdown")
        (expect (gethash "method" exit)
                :to-equal "exit")
        (expect (lsp-session-last-error session) :to-be nil)
        (expect (%fake-closed-p transport) :to-be-truthy)))))
