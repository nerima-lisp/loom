(in-package #:loom/test)

(describe
  "LSP session paths"
  (it "maps file paths and diagnostic severities"
    (expect (lsp-path-uri "/tmp/example.LISP")
            :to-equal
            "file:///tmp/example.LISP")
    (expect (lsp-path-uri "/tmp/space name#x?y%z/日本語.lisp")
            :to-equal
            "file:///tmp/space%20name%23x%3Fy%25z/%E6%97%A5%E6%9C%AC%E8%AA%9E.lisp")
    (expect (mapcar #'lsp-diagnostic-severity-name '(1 2 3 4 99))
            :to-equal
            '("error" "warning" "info" "hint" "info")))

  (it "derives language identifiers from buffer paths"
    (%with-initialized-fake-lsp-session ((transport session))
      (let* ((text-buffer (make-buffer :name "notes.txt"
                                       :path "/tmp/notes.txt"
                                       :initial-content "notes"))
             (plain-buffer (make-buffer :name "README"
                                        :path "/tmp/README"
                                        :initial-content "read me")))
        (lsp-session-sync-buffer session text-buffer)
        (lsp-session-sync-buffer session plain-buffer)
        (let* ((text-open (%fake-sent-message transport 2))
               (plain-open (%fake-sent-message transport 3)))
          (expect (gethash "languageId"
                           (gethash "textDocument"
                                    (gethash "params" text-open)))
                  :to-equal
                  "txt")
          (expect (gethash "languageId"
                           (gethash "textDocument"
                                    (gethash "params" plain-open)))
                  :to-equal
                  "plaintext")))))

  (it "refreshes through the render-loop boundary"
    (%with-started-fake-lsp-session ((transport session))
      (%fake-push-initialize-response transport)
      (lsp-session-refresh session :not-a-buffer)
      (expect (lsp-session-last-error session) :to-be-truthy)
      (setf (lsp-session-last-error session) nil)
      (lsp-session-stop session)
      (lsp-session-refresh session :not-a-buffer)
      (expect (lsp-session-last-error session) :to-be nil))))
