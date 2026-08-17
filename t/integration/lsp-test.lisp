(in-package #:loom/test)

(defclass %fake-lsp-transport ()
  ((sent :initform nil :accessor %fake-sent)
   (incoming :initform nil :accessor %fake-incoming)
   (closed-p :initform nil :accessor %fake-closed-p)))

(defmethod loom/feature/lsp::lsp-transport-send ((transport %fake-lsp-transport) json)
  (push json (%fake-sent transport)))

(defmethod loom/feature/lsp::lsp-transport-receive ((transport %fake-lsp-transport))
  (when (%fake-incoming transport)
    (pop (%fake-incoming transport))))

(defmethod loom/feature/lsp::lsp-transport-close ((transport %fake-lsp-transport))
  (setf (%fake-closed-p transport) t)
  transport)

(defun %fake-push-incoming (transport json)
  (setf (%fake-incoming transport)
        (append (%fake-incoming transport) (list json))))

(defun %fake-sent-in-order (transport)
  (reverse (%fake-sent transport)))

(defun %parse-lsp-json (json)
  (json-kit:parse
   json
   :object-type :hash-table
   :array-type :list
   :duplicate-key-policy :error
   :null-value json-kit:+json-null+
   :false-value nil))

(describe
  "LSP session"
  (it "spawns a real LSP session over a child process command"
    (when (%sandboxed-check-p)
      (skip "spawns a real \"cat\" child process; see checks.default's LOOM_SANDBOXED_CHECK in flake.nix"))
    (let ((session (make-lsp-session :command "cat")))
      (unwind-protect
           (expect (lsp-session-p session) :to-be-truthy)
        (lsp-session-stop session))))

  (it "keeps lifecycle idempotent and records initialize failures"
    (signals error (make-lsp-session))
    (let* ((transport (make-instance '%fake-lsp-transport))
           (session (make-lsp-session :transport transport)))
      (lsp-session-start session)
      (lsp-session-start session)
      (expect (length (%fake-sent-in-order transport)) :to-equal 1)
      (%fake-push-incoming
       transport
       "{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":{\"code\":-1,\"message\":\"nope\"}}")
      (lsp-session-drain session)
      (expect (lsp-session-initialized-p session) :to-be nil)
      (expect (lsp-session-last-error session) :to-equal "nope")
      (lsp-session-stop session)
      (lsp-session-stop session)
      (expect (%fake-closed-p transport) :to-be-truthy)
      (signals error (lsp-session-start session))))

  (it "covers document synchronization no-ops and changes"
    (let* ((transport (make-instance '%fake-lsp-transport))
           (session (make-lsp-session :transport transport))
           (pathless (make-buffer :name "scratch" :initial-content ""))
           (buffer (make-buffer :name "main.lisp"
                                :path "/tmp/main.lisp"
                                :initial-content "(+ 1 2)")))
      (lsp-session-sync-buffer session pathless)
      (expect (length (%fake-sent-in-order transport)) :to-equal 0)
      (lsp-session-start session)
      (lsp-session-sync-buffer session pathless)
      (expect (length (%fake-sent-in-order transport)) :to-equal 1)
      (%fake-push-incoming
       transport
       "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{}}")
      (lsp-session-drain session)
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
      (signals error (lsp-session-sync-buffer session :not-a-buffer))
      (lsp-session-stop session)))

  (it "keeps malformed transport input in the session error state"
    (let* ((transport (make-instance '%fake-lsp-transport))
           (session (make-lsp-session :transport transport)))
      (%fake-push-incoming transport "not-json")
      (lsp-session-drain session)
      (expect (lsp-session-last-error session) :to-be-truthy)
      (lsp-session-stop session)))

  (it "validates protocol messages and diagnostic paths"
    (let* ((transport (make-instance '%fake-lsp-transport))
           (session (make-lsp-session :transport transport)))
      (unwind-protect
           (progn
             (lsp-session-start session)
             (flet ((expect-error (json)
                      (setf (lsp-session-last-error session) nil)
                      (%fake-push-incoming transport json)
                      (lsp-session-drain session)
                      (expect (lsp-session-last-error session)
                              :to-be-truthy)))
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
             (%fake-push-incoming
              transport
              "{\"jsonrpc\":\"2.0\",\"method\":\"$/progress\"}")
             (lsp-session-drain session)
             (expect (lsp-session-last-error session) :to-be nil)
             (%fake-push-incoming
              transport
              "{\"jsonrpc\":\"2.0\",\"id\":99,\"result\":{}}")
             (lsp-session-drain session)
             (expect (loom/feature/lsp::lsp-session-pending-initialize-id session)
                     :to-equal 1)
             (%fake-push-incoming
              transport
              "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/publishDiagnostics\",\"params\":{\"uri\":\"file:///tmp/main.lisp\",\"diagnostics\":[{\"range\":{\"start\":{\"line\":0,\"character\":1},\"end\":{\"line\":0,\"character\":2}},\"message\":\"bad\",\"severity\":null,\"source\":null,\"code\":7}]}}")
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
             (expect (lsp-session-diagnostics session nil) :to-be nil))
        (lsp-session-stop session))))

  (it "handles initialize response variants"
    (dolist (response-and-expected
              '(("{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":\"server down\"}"
                 "server down")
                ("{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":{\"code\":-1}}"
                 t)
                ("{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":42}"
                 "42")))
      (let* ((transport (make-instance '%fake-lsp-transport))
             (session (make-lsp-session :transport transport)))
        (unwind-protect
             (progn
               (lsp-session-start session)
               (%fake-push-incoming transport (first response-and-expected))
               (lsp-session-drain session)
               (if (eq (second response-and-expected) t)
                   (expect (lsp-session-last-error session) :to-be-truthy)
                   (expect (lsp-session-last-error session)
                           :to-equal
                           (second response-and-expected)))
               (expect (lsp-session-initialized-p session) :to-be nil))
          (lsp-session-stop session))))
    (let* ((transport (make-instance '%fake-lsp-transport))
           (session (make-lsp-session :transport transport)))
      (unwind-protect
           (progn
             (lsp-session-start session)
             (%fake-push-incoming
              transport
              "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{},\"error\":null}")
             (lsp-session-drain session)
             (expect (lsp-session-initialized-p session) :to-be-truthy)
             (expect (lsp-session-last-error session) :to-be nil)
             (expect (%fake-sent-in-order transport) :to-have-length 2))
        (lsp-session-stop session))))

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

  (it "initializes through a transport seam"
    (let* ((transport (make-instance '%fake-lsp-transport))
           (session (make-lsp-session :transport transport
                                      :root-uri "file:///tmp")))
      (lsp-session-start session)
      (let* ((sent (%fake-sent-in-order transport))
             (request (%parse-lsp-json (first sent)))
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
      (%fake-push-incoming
       transport
       "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"capabilities\":{\"hoverProvider\":true},\"serverInfo\":{\"name\":\"fake\",\"version\":\"1\"}}}")
      (lsp-session-drain session)
      (expect (lsp-session-initialized-p session) :to-be-truthy)
      (expect (gethash "hoverProvider"
                       (lsp-session-server-capabilities session))
              :to-be-truthy)
      (expect (gethash "name" (lsp-session-server-info session))
              :to-equal
              "fake")
      (let* ((messages (%fake-sent-in-order transport))
             (initialized (%parse-lsp-json (second messages))))
        (expect (gethash "method" initialized)
                :to-equal "initialized"))
      (%fake-push-incoming
       transport
       "{\"jsonrpc\":\"2.0\",\"id\":2,\"result\":null}")
      (lsp-session-stop session)
      (expect (%fake-closed-p transport) :to-be-truthy)
      (let* ((messages (%fake-sent-in-order transport))
             (shutdown (%parse-lsp-json (third messages)))
             (exit (%parse-lsp-json (fourth messages))))
        (expect messages :to-have-length 4)
        (expect (gethash "method" shutdown)
                :to-equal "shutdown")
        (expect (gethash "id" shutdown)
                :to-equal 2)
        (expect (gethash "method" exit)
                :to-equal "exit"))))
  (it "falls back to exit when shutdown is not acknowledged"
    (let* ((transport (make-instance '%fake-lsp-transport))
           (session (make-lsp-session :transport transport)))
      (lsp-session-start session)
      (%fake-push-incoming
       transport
       "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{}}")
      (lsp-session-drain session)
      (lsp-session-stop session :timeout 0)
      (let* ((messages (%fake-sent-in-order transport))
             (shutdown (%parse-lsp-json (third messages)))
             (exit (%parse-lsp-json (fourth messages))))
        (expect messages :to-have-length 4)
        (expect (gethash "method" shutdown)
                :to-equal "shutdown")
        (expect (gethash "method" exit)
                :to-equal "exit")
        (expect (lsp-session-last-error session) :to-be nil)
        (expect (%fake-closed-p transport) :to-be-truthy))))
  (it "synchronizes a buffer and stores published diagnostics"
    (let* ((transport (make-instance '%fake-lsp-transport))
           (session (make-lsp-session :transport transport))
           (buffer (make-buffer :name "main.lisp"
                                :path "/tmp/main.lisp"
                                :initial-content "(+ 1 2)")))
      (lsp-session-start session)
      (%fake-push-incoming
       transport
       "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{}}")
      (lsp-session-drain session)
      (lsp-session-sync-buffer session buffer)
      (let* ((messages (%fake-sent-in-order transport))
             (open (%parse-lsp-json (third messages)))
             (text-document
               (gethash "params" open)))
        (expect (gethash "method" open)
                :to-equal "textDocument/didOpen")
        (expect (gethash "textDocument" text-document)
                :to-be-truthy))
      (%fake-push-incoming
       transport
       "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/publishDiagnostics\",\"params\":{\"uri\":\"file:///tmp/main.lisp\",\"diagnostics\":[{\"range\":{\"start\":{\"line\":0,\"character\":1},\"end\":{\"line\":0,\"character\":2}},\"message\":\"bad\",\"severity\":1,\"source\":\"fake\"}]}}")
      (lsp-session-drain session)
      (let ((diagnostics (lsp-session-diagnostics session buffer)))
        (expect diagnostics :to-have-length 1)
        (expect (lsp-diagnostic-message (first diagnostics)) :to-equal "bad")
        (expect (lsp-diagnostic-severity (first diagnostics)) :to-equal 1)
        (expect (lsp-diagnostic-source (first diagnostics)) :to-equal "fake"))
      (lsp-session-stop session)))
  (it "derives language identifiers from buffer paths"
    (let* ((transport (make-instance '%fake-lsp-transport))
           (session (make-lsp-session :transport transport))
           (text-buffer (make-buffer :name "notes.txt"
                                      :path "/tmp/notes.txt"
                                      :initial-content "notes"))
           (plain-buffer (make-buffer :name "README"
                                      :path "/tmp/README"
                                      :initial-content "read me")))
      (unwind-protect
           (progn
             (lsp-session-start session)
             (%fake-push-incoming
              transport
              "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{}}")
             (lsp-session-drain session)
             (lsp-session-sync-buffer session text-buffer)
             (lsp-session-sync-buffer session plain-buffer)
             (let* ((messages (%fake-sent-in-order transport))
                    (text-open (%parse-lsp-json (third messages)))
                    (plain-open (%parse-lsp-json (fourth messages))))
               (expect (gethash "languageId"
                                (gethash "textDocument"
                                         (gethash "params" text-open)))
                       :to-equal
                       "txt")
               (expect (gethash "languageId"
                                (gethash "textDocument"
                                         (gethash "params" plain-open)))
                       :to-equal
                       "plaintext")))
        (lsp-session-stop session))))
  (it "refreshes through the render-loop boundary"
    (let* ((transport (make-instance '%fake-lsp-transport))
           (session (make-lsp-session :transport transport)))
      (unwind-protect
           (progn
             (lsp-session-start session)
             (%fake-push-incoming
              transport
              "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{}}")
             (lsp-session-refresh session :not-a-buffer)
             (expect (lsp-session-last-error session) :to-be-truthy)
             (setf (lsp-session-last-error session) nil)
             (lsp-session-stop session)
             (lsp-session-refresh session :not-a-buffer)
             (expect (lsp-session-last-error session) :to-be nil))
        (lsp-session-stop session))))
  (it "round-trips a framed message through a child process"
    (when (%sandboxed-check-p)
      (skip "spawns a real \"cat\" child process; see checks.default's LOOM_SANDBOXED_CHECK in flake.nix"))
    (let ((process (loom/feature/lsp::make-lsp-process "cat"))
          (received nil))
      (unwind-protect
           (progn
             (loom/feature/lsp::lsp-transport-send process "{\"ok\":true}")
             (loop repeat 200
                   do (setf received
                            (loom/feature/lsp::lsp-transport-receive process))
                      (when received (return))
                      (sleep 0.01))
             (expect received :to-equal "{\"ok\":true}"))
        (loom/feature/lsp::lsp-transport-close process))
      (signals error
        (loom/feature/lsp::lsp-transport-send process "{\"ok\":false}"))
      (expect (loom/feature/lsp::lsp-transport-receive process)
              :to-be nil)
        (expect (loom/feature/lsp::lsp-transport-close process)
              :to-be process))))

(describe
  "LSP project discovery"
  (it "uses the nearest .loom-lsp command and skips comments and blank lines"
    (host-kit:with-temporary-directory (directory)
      (let* ((directory (truename directory))
             (nested (merge-pathnames "nested/" directory))
             (source (merge-pathnames "nested/main.lisp" directory))
             (root-config (merge-pathnames ".loom-lsp" directory))
             (nested-config (merge-pathnames ".loom-lsp" nested)))
        (ensure-directories-exist source)
        (host-kit:write-file-string
         (format nil "# root command~%~%  root-server --stdio  ~%")
         root-config)
        (host-kit:write-file-string
         (format nil " # nested comment~%~% nested-server --stdio ~%")
         nested-config)
        (multiple-value-bind (command root configuration)
            (lsp-discover-command source)
          (expect command :to-equal "nested-server --stdio")
          (expect (namestring root)
                  :to-equal
                  (namestring (truename nested)))
          (expect (namestring configuration)
                  :to-equal
                  (namestring (truename nested-config)))))))

  (it "returns no discovery for missing or commandless configuration"
    (host-kit:with-temporary-directory (directory)
      (let* ((directory (truename directory))
             (source (merge-pathnames "main.lisp" directory))
             (configuration (merge-pathnames ".loom-lsp" directory)))
        (host-kit:write-file-string "source" source)
        (multiple-value-bind (command root config)
            (lsp-discover-command source)
          (expect command :to-be nil)
          (expect root :to-be nil)
          (expect config :to-be nil))
        (host-kit:write-file-string
         (format nil "# comment~%~%  ~%")
         configuration)
        (multiple-value-bind (command root config)
            (lsp-discover-command source)
          (expect command :to-be nil)
          (expect root :to-be nil)
          (expect config :to-be nil))))))

(describe
  "LSP commands"
  (it "renders refreshed diagnostics in a registered buffer"
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
           (progn
             (lsp-session-start session)
             (%fake-push-incoming
              transport
              "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{}}")
             (%fake-push-incoming
              transport
              "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/publishDiagnostics\",\"params\":{\"uri\":\"file:///tmp/main.lisp\",\"diagnostics\":[{\"range\":{\"start\":{\"line\":0,\"character\":1},\"end\":{\"line\":0,\"character\":2}},\"message\":\"bad\",\"severity\":1,\"source\":\"fake\"}]}}")
             (setf (editor-state-lsp-session state) session)
             (let ((*editor-state* state))
               (loom/feature/lsp:lsp-diagnostics)
               (let ((diagnostics-buffer (%selected-test-buffer)))
                 (expect (buffer-name diagnostics-buffer)
                         :to-equal "*Loom-Diagnostics*")
                 (expect (buffer-text diagnostics-buffer)
                         :to-contain "bad")
                 (expect (loom:minibuffer-message-string
                          (editor-state-minibuffer state))
                         :to-equal "LSP diagnostics refreshed.")))
             (loom/feature/window:window-set-buffer
              (loom/feature/window:window-tree-selected-window
               (editor-state-window-tree state))
              buffer)
             (%fake-push-incoming
              transport
              "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/publishDiagnostics\",\"params\":{\"uri\":\"file:///tmp/main.lisp\",\"diagnostics\":[]}}")
             (let ((*editor-state* state))
               (loom/feature/lsp:lsp-diagnostics)
               (expect (buffer-text (%selected-test-buffer))
                       :to-contain
                       "No diagnostics.")))
        (lsp-session-stop session))))

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
          (lsp-session-stop session)))))

  (it "starts LSP sessions through the command prompt"
    (%with-minibuffer-state (minibuffer "")
      (lsp-start)
      (funcall (loom::%minibuffer-on-confirm minibuffer) " ")
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal
              "LSP command cannot be empty"))
    (%with-minibuffer-state (minibuffer "")
      (let* ((transport (make-instance '%fake-lsp-transport))
             (session (make-lsp-session :transport transport)))
        (lsp-session-stop session)
        (with-replaced-function
            (loom/feature/lsp::make-lsp-session
             (lambda (&rest arguments)
               (declare (ignore arguments))
               session))
          (lsp-start)
          (funcall (loom::%minibuffer-on-confirm minibuffer) "closed-server"))
        (expect (loom:minibuffer-message-string minibuffer)
                :to-contain
                "LSP start failed:")
        (expect (%fake-closed-p transport) :to-be-truthy)))
    (%with-minibuffer-state (minibuffer "")
      (let* ((buffer (make-buffer :name "main.lisp"
                                   :path "/tmp/main.lisp"
                                   :initial-content "(+ 1 2)"))
             (window (window-tree-selected-window
                      (editor-state-window-tree *editor-state*)))
             (old-transport (make-instance '%fake-lsp-transport))
             (old-session (make-lsp-session :transport old-transport))
             (new-transport (make-instance '%fake-lsp-transport))
             (original-make-session
               (symbol-function 'loom/feature/lsp::make-lsp-session))
             (new-session nil)
             (captured-arguments nil))
        (unwind-protect
             (progn
               (window-set-buffer window buffer)
               (%register-buffer buffer)
               (setf (editor-state-lsp-session *editor-state*) old-session)
               (with-replaced-function
                   (loom/feature/lsp::make-lsp-session
                    (lambda (&rest arguments)
                      (setf captured-arguments arguments
                            new-session
                            (apply original-make-session
                                   :transport new-transport
                                   arguments))
                      new-session))
                 (lsp-start)
                 (funcall (loom::%minibuffer-on-confirm minibuffer)
                          "fake-server"))
               (expect (editor-state-lsp-session *editor-state*)
                       :to-be
                       new-session)
               (expect (%fake-closed-p old-transport) :to-be-truthy)
               (expect (%fake-closed-p new-transport) :to-be nil)
               (let* ((request
                        (%parse-lsp-json
                         (first (%fake-sent-in-order new-transport))))
                      (params (gethash "params" request)))
                 (expect (gethash "method" request)
                         :to-equal
                         "initialize")
                 (expect (gethash "rootUri" params)
                         :to-equal
                         "file:///tmp/"))
               (expect (getf captured-arguments :root-uri)
                       :to-equal
                       "file:///tmp/")
               (expect (loom:minibuffer-message-string minibuffer)
                       :to-equal
                       "LSP started."))
          (lsp-session-stop old-session)
          (when new-session
               (lsp-session-stop new-session))))))

  (it "uses the discovered command and project root when RET confirms it"
    (host-kit:with-temporary-directory (directory)
      (let* ((directory (truename directory))
             (path (merge-pathnames "src/main.lisp" directory))
             (configuration (merge-pathnames ".loom-lsp" directory)))
        (ensure-directories-exist path)
        (host-kit:write-file-string "(+ 1 2)" path)
        (host-kit:write-file-string
         (format nil "# project LSP~%~% fake-server --stdio ~%")
         configuration)
        (%with-minibuffer-state (minibuffer "")
          (let* ((buffer (make-buffer :name "main.lisp"
                                      :path path
                                      :initial-content "(+ 1 2)"))
                 (window (window-tree-selected-window
                          (editor-state-window-tree *editor-state*)))
                 (transport (make-instance '%fake-lsp-transport))
                 (original-make-session
                   (symbol-function 'loom/feature/lsp::make-lsp-session))
                 (new-session nil)
                 (captured-arguments nil))
            (unwind-protect
                 (progn
                   (window-set-buffer window buffer)
                   (%register-buffer buffer)
                   (with-replaced-function
                       (loom/feature/lsp::make-lsp-session
                        (lambda (&rest arguments)
                          (setf captured-arguments arguments
                                new-session
                                (apply original-make-session
                                       :transport transport
                                       arguments))
                          new-session))
                     (lsp-start)
                     (expect (minibuffer-prompt-string minibuffer)
                             :to-equal
                             "LSP command [RET for fake-server --stdio]: ")
                     (funcall (loom::%minibuffer-on-confirm minibuffer) ""))
                   (expect (getf captured-arguments :command)
                           :to-equal
                           "fake-server --stdio")
                   (expect (getf captured-arguments :directory)
                           :to-equal
                           directory)
                   (expect (getf captured-arguments :root-uri)
                           :to-equal
                           (lsp-path-uri directory))
                   (let* ((request
                            (%parse-lsp-json
                             (first (%fake-sent-in-order transport))))
                          (params (gethash "params" request)))
                     (expect (gethash "rootUri" params)
                             :to-equal
                             (lsp-path-uri directory)))
                   (expect (loom:minibuffer-message-string minibuffer)
                           :to-equal
                           "LSP started."))
              (when new-session
                (lsp-session-stop new-session))))))))

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
