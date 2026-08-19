(in-package #:loom/test)

(describe
  "LSP session initialization"
  (it "initializes through a transport seam"
    (%with-started-fake-lsp-session
        ((transport session) :root-uri "file:///tmp")
      (let* ((request (%fake-sent-message transport 0))
             (params (gethash "params" request))
             (capabilities (gethash "capabilities" params))
             (workspace (gethash "workspace" capabilities))
             (text-document (gethash "textDocument" capabilities))
             (synchronization (gethash "synchronization" text-document))
             (diagnostics (gethash "publishDiagnostics" capabilities))
             (workspace-folders (gethash "workspaceFolders" params))
             (client-info (gethash "clientInfo" params)))
        (expect (gethash "method" request)
                :to-equal "initialize")
        (expect (gethash "id" request)
                :to-equal 1)
        (expect (gethash "name" client-info)
                :to-equal "Loom")
        (expect (gethash "version" client-info)
                :to-equal "0.1.0")
        (expect (gethash "workspaceFolders" workspace)
                :to-be-truthy)
        (expect (gethash "dynamicRegistration" synchronization)
                :to-be-truthy)
        (expect (gethash "relatedInformation" diagnostics)
                :to-be-truthy)
        (expect (gethash "uri" (first workspace-folders))
                :to-equal
                "file:///tmp")
        (expect (gethash "name" (first workspace-folders))
                :to-equal
                "Loom workspace"))
      (%fake-push-initialize-response
       transport
       "{\"capabilities\":{\"hoverProvider\":true},\"serverInfo\":{\"name\":\"fake\",\"version\":\"1\"}}")
      (lsp-session-drain session)
      (expect (lsp-session-initialized-p session) :to-be-truthy)
      (expect (gethash "hoverProvider"
                       (lsp-session-server-capabilities session))
              :to-be-truthy)
      (expect (gethash "name" (lsp-session-server-info session))
              :to-equal
              "fake")
      (let ((initialized (%fake-sent-message transport 1)))
        (expect (gethash "method" initialized)
                :to-equal "initialized")))))
