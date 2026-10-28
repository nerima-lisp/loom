(in-package #:loom/test)

(defun %lsp-formatting-command ()
  (let ((symbol (find-symbol "LSP-FORMAT-BUFFER" "LOOM/FEATURE/LSP")))
    (and symbol (fboundp symbol) symbol)))

(defun %lsp-formatting-reply (transport session result)
  (%fake-push-and-drain transport
                        session
                        (format nil
                                "{\"jsonrpc\":\"2.0\",\"id\":~D,\"result\":~A}"
                                (%lsp-last-request-id transport)
                                result)))

(describe "LSP formatting"
          (it "advertises document formatting support during initialize"
              (%with-started-fake-lsp-session ((transport session))
                                              (expect session :to-be-truthy)
                                              (let* ((initialize
                                                      (%fake-sent-message
                                                       transport
                                                       0))
                                                     (params
                                                      (and
                                                       (hash-table-p initialize)
                                                       (gethash "params"
                                                                initialize)))
                                                     (capabilities
                                                      (and (hash-table-p params)
                                                           (gethash
                                                            "capabilities"
                                                            params)))
                                                     (text-document
                                                      (and
                                                       (hash-table-p
                                                        capabilities)
                                                       (gethash "textDocument"
                                                                capabilities)))
                                                     (formatting
                                                      (and
                                                       (hash-table-p
                                                        text-document)
                                                       (gethash "formatting"
                                                                text-document))))
                                                (expect
                                                 (and (hash-table-p formatting)
                                                      (gethash
                                                       "dynamicRegistration"
                                                       formatting))
                                                 :to-be
                                                 t))))
          (it "registers M-x lsp-format-buffer and reports a missing session"
              (let ((command (%lsp-formatting-command)))
                (expect command :to-be-truthy)
                (when command
                  (let ((*editor-state* (%lsp-navigation-state)))
                    (funcall command)
                    (expect
                     (minibuffer-message-string
                      (editor-state-minibuffer *editor-state*))
                     :to-equal
                     "No LSP session for this buffer")))))
          (it
           "does not send a request when documentFormattingProvider is absent"
           (let ((command (%lsp-formatting-command)))
             (expect command :to-be-truthy)
             (when command
               (%with-lsp-navigation
                (transport session buffer :capabilities "{\"capabilities\":{}}")
                (let ((before (length (%fake-sent-in-order transport))))
                  (funcall command)
                  (expect
                   (minibuffer-message-string
                    (editor-state-minibuffer *editor-state*))
                   :to-equal
                   "Server does not provide formatting")
                  (expect (length (%fake-sent-in-order transport))
                          :to-equal
                          before))))))
          (it "syncs dirty text before sending formatting with mode options"
              (let ((command (%lsp-formatting-command)))
                (expect command :to-be-truthy)
                (when command
                  (%with-lsp-navigation
                   (transport session buffer
                              :mode :python
                              :content
                              "foo"
                              :capabilities
                              "{\"capabilities\":{\"documentFormattingProvider\":true}}")
                   (lsp-session-sync-buffer session buffer)
                   (buffer-insert-string buffer "!")
                   (expect (buffer-text buffer) :to-equal "!foo")
                   (progn
  (expect
   (lsp-document-text
    (gethash (lsp-path-uri (buffer-path buffer))
             (loom/feature/lsp::lsp-session-documents session)))
   :to-equal
   "foo")
  (expect
   (lsp-document-version
    (gethash (lsp-path-uri (buffer-path buffer))
             (loom/feature/lsp::lsp-session-documents session)))
   :to-equal
   1))
                   (funcall command)
                   (let* ((messages (%fake-sent-in-order transport))
                          (methods
                           (mapcar
                            (lambda (wire)
                              (gethash "method" (%parse-lsp-json wire)))
                            messages))
                          (change-index
                           (position "textDocument/didChange"
                                     methods
                                     :test
                                     #'equal))
                          (format-index
                           (position "textDocument/formatting"
                                     methods
                                     :test
                                     #'equal)))
                     (progn
  (expect methods
          :to-equal
          (list "initialize"
                "initialized"
                "textDocument/didOpen"
                "textDocument/didChange"
                "textDocument/formatting"))
  (expect
   (and change-index format-index (< change-index format-index))
   :to-be-truthy)
  (let ((document
          (gethash (lsp-path-uri (buffer-path buffer))
                   (loom/feature/lsp::lsp-session-documents session))))
    (expect (lsp-document-text document) :to-equal "!foo")
    (expect (lsp-document-version document) :to-equal 2)))
                     (expect (%lsp-last-request-method transport)
                             :to-equal
                             "textDocument/formatting")
                     (when format-index
                       (let* ((request
                               (%parse-lsp-json (nth format-index messages)))
                              (params (gethash "params" request))
                              (document (gethash "textDocument" params))
                              (options (gethash "options" params)))
                         (expect (gethash "uri" document)
                                 :to-equal
                                 (lsp-path-uri (buffer-path buffer)))
                         (expect (gethash "tabSize" options) :to-equal 4)
                         (expect (gethash "insertSpaces" options) :to-be t))))))))
          (it "applies returned TextEdits and syncs the formatted document"
              (let ((command (%lsp-formatting-command)))
                (expect command :to-be-truthy)
                (when command
                  (%with-lsp-navigation
                   (transport session
                              buffer
                              :content
                              "one two"
                              :capabilities
                              "{\"capabilities\":{\"documentFormattingProvider\":true}}")
                   (funcall command)
                   (let* ((uri (lsp-path-uri (buffer-path buffer)))
               (workspace-edit
                 (%parse-lsp-json
                  (format nil
                          "{\"changes\":{\"~A\":[{\"range\":{\"start\":{\"line\":0,\"character\":0},\"end\":{\"line\":0,\"character\":7}},\"newText\":\"formatted\"}]}}"
                          uri)))
               (changes (gethash "changes" workspace-edit))
               (edits (gethash uri changes)))
          (expect (type-of edits) :to-equal (quote cons))
          (expect (hash-table-p (first edits)) :to-be t)
          (expect (hash-table-p (gethash "range" (first edits))) :to-be t)
          (expect (hash-table-p workspace-edit) :to-be t)
          (expect (hash-table-p changes) :to-be t)
          (expect (gethash uri changes) :to-equal edits))
                   (%lsp-formatting-reply transport
                                          session
                                          (format nil
                                                  "[{\"range\":{\"start\":{\"line\":0,\"character\":0},\"end\":{\"line\":0,\"character\":7}},\"newText\":\"formatted\"}]"))
                   (progn
                     (expect
                      (minibuffer-message-string
                       (editor-state-minibuffer *editor-state*))
                      :to-equal
                      "Formatting applied")
                     (expect (buffer-text buffer) :to-equal "formatted"))
                   (expect
                    (lsp-document-text
                     (gethash (lsp-path-uri (buffer-path buffer))
                              (loom/feature/lsp::lsp-session-documents session)))
                    :to-equal
                    "formatted")
                   (expect (%lsp-last-request-method transport)
                           :to-equal
                           "textDocument/didChange")))))
          (it "discards a stale formatting response after the buffer changes"
              (let ((command (%lsp-formatting-command)))
                (expect command :to-be-truthy)
                (when command
                  (%with-lsp-navigation
                   (transport session buffer
                              :mode :python
                              :content "foo"
                              :capabilities
                              "{\"capabilities\":{\"documentFormattingProvider\":true}}")
                   (funcall command)
                   (let* ((request-id (%lsp-last-request-id transport))
                          (uri (lsp-path-uri (buffer-path buffer)))
                          (document
                           (gethash uri
                                    (loom/feature/lsp::lsp-session-documents session))))
                     (expect (lsp-document-text document) :to-equal "foo")
                     (expect (lsp-document-version document) :to-equal 1)
                     (buffer-insert-string buffer "!")
                     (lsp-session-sync-buffer session buffer)
                     (expect (buffer-text buffer) :to-equal "!foo")
                     (expect (lsp-document-text document) :to-equal "!foo")
                     (expect (lsp-document-version document) :to-equal 2)
                     (%fake-push-and-drain
                      transport session
                      (format nil
                              "{\"jsonrpc\":\"2.0\",\"id\":~D,\"result\":[{\"range\":{\"start\":{\"line\":0,\"character\":0},\"end\":{\"line\":0,\"character\":3}},\"newText\":\"formatted\"}]}"
                              request-id))
                     (expect (buffer-text buffer) :to-equal "!foo")
                     (expect (lsp-document-text document) :to-equal "!foo")
                     (expect
                      (minibuffer-message-string
                       (editor-state-minibuffer *editor-state*))
                      :to-equal
                      "Formatting response discarded because the buffer changed or closed"))))))
          (it "discards a formatting response after the document closes"
              (let ((command (%lsp-formatting-command)))
                (expect command :to-be-truthy)
                (when command
                  (%with-lsp-navigation
                   (transport session buffer
                              :mode :python
                              :content "foo"
                              :capabilities
                              "{\"capabilities\":{\"documentFormattingProvider\":true}}")
                   (funcall command)
                   (let* ((request-id (%lsp-last-request-id transport))
                          (uri (lsp-path-uri (buffer-path buffer)))
                          (editor-session
                           (loom/core/editor-session:editor-state-session
                            *editor-state*)))
                     (loom/feature/buffers:unregister-buffer
                      editor-session buffer :reason :test)
                     (expect (gethash uri
                                      (loom/feature/lsp::lsp-session-documents session))
                             :to-be
                             nil)
                     (%fake-push-and-drain
                      transport session
                      (format nil
                              "{\"jsonrpc\":\"2.0\",\"id\":~D,\"result\":[{\"range\":{\"start\":{\"line\":0,\"character\":0},\"end\":{\"line\":0,\"character\":3}},\"newText\":\"formatted\"}]}"
                              request-id))
                     (expect (buffer-text buffer) :to-equal "foo")
                     (expect
                      (minibuffer-message-string
                       (editor-state-minibuffer *editor-state*))
                      :to-equal
                      "Formatting response discarded because the buffer changed or closed"))))))
          (it "treats null and empty results as no edits"
              (let ((command (%lsp-formatting-command)))
                (expect command :to-be-truthy)
                (when command
                  (%with-lsp-navigation
                   (transport session
                              buffer
                              :content
                              "unchanged"
                              :capabilities
                              "{\"capabilities\":{\"documentFormattingProvider\":true}}")
                   (funcall command)
                   (%lsp-formatting-reply transport session "null")
                   (expect (buffer-text buffer) :to-equal "unchanged")
                   (expect
                    (minibuffer-message-string
                     (editor-state-minibuffer *editor-state*))
                    :to-equal
                    "No formatting edits returned")
                   (funcall command)
                   (%lsp-formatting-reply transport session "[]")
                   (expect (buffer-text buffer) :to-equal "unchanged")
                   (expect
                    (minibuffer-message-string
                     (editor-state-minibuffer *editor-state*))
                    :to-equal
                    "No formatting edits returned")))))
          (it "reports server errors without changing the buffer"
              (let ((command (%lsp-formatting-command)))
                (expect command :to-be-truthy)
                (when command
                  (%with-lsp-navigation
                   (transport session
                              buffer
                              :content
                              "unchanged"
                              :capabilities
                              "{\"capabilities\":{\"documentFormattingProvider\":true}}")
                   (funcall command)
                   (%fake-push-and-drain transport
                                         session
                                         (format nil
                                                 "{\"jsonrpc\":\"2.0\",\"id\":~D,\"error\":{\"code\":-32603,\"message\":\"boom\"}}"
                                                 (%lsp-last-request-id
                                                  transport)))
                   (expect (buffer-text buffer) :to-equal "unchanged")
                   (expect
                    (minibuffer-message-string
                     (editor-state-minibuffer *editor-state*))
                    :to-equal
                    "Formatting failed: boom")))))
          (it "rejects malformed and overlapping edits without partial changes"
              (let ((command (%lsp-formatting-command)))
                (expect command :to-be-truthy)
                (when command
                  (%with-lsp-navigation
                   (transport session
                              buffer
                              :content
                              "foo"
                              :capabilities
                              "{\"capabilities\":{\"documentFormattingProvider\":true}}")
                   (funcall command)
                   (%lsp-formatting-reply transport session "{}")
                   (expect (buffer-text buffer) :to-equal "foo")
                   (expect
                    (search "Formatting rejected:"
                            (minibuffer-message-string
                             (editor-state-minibuffer *editor-state*)))
                    :to-be-truthy)
                   (funcall command)
                   (%lsp-formatting-reply transport
                                          session
                                          "[{\"range\":{\"start\":{\"line\":0,\"character\":0},\"end\":{\"line\":0,\"character\":3}},\"newText\":\"bar\"},{\"range\":{\"start\":{\"line\":0,\"character\":1},\"end\":{\"line\":0,\"character\":2}},\"newText\":\"X\"}]")
                   (expect (buffer-text buffer) :to-equal "foo")
                   (expect
                    (search "Formatting rejected:"
                            (minibuffer-message-string
                             (editor-state-minibuffer *editor-state*)))
                    :to-be-truthy))))))
