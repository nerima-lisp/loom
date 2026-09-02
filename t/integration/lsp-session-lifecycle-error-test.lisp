(in-package #:loom/test)

(describe
  "LSP session lifecycle errors"
  (it "spawns a real LSP session over a child process command"
    (when (%sandboxed-check-p)
      (skip "spawns a real \"cat\" child process; see checks.default's LOOM_SANDBOXED_CHECK in flake.nix"))
    (let ((session (make-lsp-session :command "cat")))
      (unwind-protect
           (expect (lsp-session-p session) :to-be-truthy)
        (lsp-session-stop session))))

  (it "keeps lifecycle idempotent and records initialize failures"
    (signals error (make-lsp-session))
    (%with-started-fake-lsp-session ((transport session))
      (lsp-session-start session)
      (expect (length (%fake-sent-in-order transport)) :to-equal 1)
      (%fake-push-and-drain
       transport
       session
       "{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":{\"code\":-1,\"message\":\"nope\"}}")
      (expect (lsp-session-initialized-p session) :to-be nil)
      (expect (lsp-session-last-error session) :to-equal "nope")
      (lsp-session-stop session)
      (lsp-session-stop session)
      (expect (%fake-closed-p transport) :to-be-truthy)
      (signals error (lsp-session-start session))))

  (it "keeps malformed transport input in the session error state"
    (%with-fake-lsp-session ((transport session))
      (%fake-push-and-drain transport session "not-json")
      (expect (lsp-session-last-error session) :to-be-truthy)))

  (it "rejects restarting a session while shutdown is pending"
    (%with-initialized-fake-lsp-session ((transport session))
      (setf (loom/feature/lsp::lsp-session-pending-shutdown-id session) 99)
      (signals error (lsp-session-start session))))

  (it "refreshes safely before initialization and after shutdown"
    (%with-fake-lsp-session ((transport session))
      (lsp-session-refresh session nil)
      (lsp-session-stop session)
      (lsp-session-refresh session nil)
      (expect (lsp-session-last-error session) :to-be nil)))

  (it "handles initialize response variants"
    (dolist (response-and-expected
              '(("{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":\"server down\"}"
                 "server down")
                ("{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":{\"code\":-1}}"
                 t)
                ("{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":42}"
                 "42")
                ("{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":null}"
                 t)))
      (%with-started-fake-lsp-session ((transport session))
        (%expect-initialize-error
            (transport session)
            (first response-and-expected)
            (second response-and-expected))))
    (%with-started-fake-lsp-session ((transport session))
      (%fake-push-and-drain
       transport
       session
       "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{},\"error\":null}")
      (expect (lsp-session-initialized-p session) :to-be-truthy)
      (expect (lsp-session-last-error session) :to-be nil)
      (expect (%fake-sent-in-order transport) :to-have-length 2)))

  (it "records malformed initialize result shapes"
    (dolist (result
              '("42"
                "{\"capabilities\":42}"
                "{\"serverInfo\":42}"
                "{\"capabilities\":{},\"serverInfo\":[]}"))
      (%with-started-fake-lsp-session ((transport session))
        (%fake-push-initialize-response transport result)
        (lsp-session-drain session)
        (expect (lsp-session-initialized-p session) :to-be nil)
        (expect (lsp-session-last-error session) :to-be-truthy))))

  (it "records shutdown response errors before finishing"
    (%with-initialized-fake-lsp-session ((transport session))
      (%fake-push-incoming
       transport
       "{\"jsonrpc\":\"2.0\",\"id\":2,\"error\":{\"code\":-1,\"message\":\"busy\"}}")
      (lsp-session-stop session)
      (expect (lsp-session-last-error session) :to-equal "busy")
      (expect (%fake-closed-p transport) :to-be-truthy)))

  (it "records shutdown send failures before finishing"
    (%with-initialized-fake-lsp-session ((transport session))
      (setf (%fake-send-error transport) "send failed")
      (lsp-session-stop session)
      (expect (lsp-session-last-error session) :to-equal "send failed")
      (expect (%fake-closed-p transport) :to-be-truthy))))
