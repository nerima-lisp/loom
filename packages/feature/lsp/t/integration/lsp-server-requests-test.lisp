(in-package #:loom/test)

(defun %wp7-frame (session)
  (if *editor-state*
      (let ((editor-session
              (loom/core/editor-session:editor-state-session *editor-state*)))
        (unless (loom/feature/lsp::lsp-session-root-path session)
          (setf (loom/feature/lsp::lsp-session-root-path session) #P"/tmp/wp7/"))
        (unless (loom/feature/lsp::lsp-session-language-id session)
          (setf (loom/feature/lsp::lsp-session-language-id session) "plaintext"))
        (loom/feature/lsp::%lsp-register-session editor-session session)
        (lsp-refresh-editor-state *editor-state*))
      (lsp-session-drain session)))

(defun %wp7-request (transport session id method &optional (params "{}"))
  (%fake-push-and-drain
   transport session
   (json-kit:stringify
    (json-kit:make-json-object
     (list (cons "jsonrpc" "2.0") (cons "id" id)
           (cons "method" method) (cons "params" (%parse-lsp-json params))))))
  (%wp7-frame session))

(defun %wp7-response (transport id)
  (let ((responses
          (remove-if-not
           (lambda (message)
             (and (equal (gethash "id" message) id)
                  (not (nth-value 1 (gethash "method" message)))))
           (mapcar #'%parse-lsp-json (%fake-sent-in-order transport)))))
    (expect responses :to-have-length 1)
    (first responses)))

(defun %wp7-type (minibuffer text)
  (loop for character across text
        do (minibuffer-handle-key
            minibuffer
            (cl-tty-kit:make-key-event :type :character :code character))))

(defun %wp7-key (minibuffer code)
  (minibuffer-handle-key
   minibuffer (cl-tty-kit:make-key-event :type :special :code code)))

(describe
  "LSP server text display (WP7)"
  (it "sanitizes server error messages before recording them"
    (%with-started-fake-lsp-session ((transport session))
      (%fake-push-and-drain transport session
                            "{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":{\"code\":-1,\"message\":\"Failure\\u001b\\u0085\"}}")
      (expect (lsp-session-last-error session)
              :to-equal (format nil "Failure~C~C" (code-char #xfffd) (code-char #xfffd)))))

  (it "sanitizes diagnostic messages before storing them for display"
    (%with-fake-lsp-session ((transport session))
      (%fake-push-and-drain
       transport session
       "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/publishDiagnostics\",\"params\":{\"uri\":\"file:///tmp/wp7\",\"diagnostics\":[{\"range\":{\"start\":{\"line\":0,\"character\":0},\"end\":{\"line\":0,\"character\":1}},\"message\":\"Error\\u001b\",\"source\":\"server\\u0085\"}]}}")
      (let ((diagnostic (first (gethash "file:///tmp/wp7"
                                        (loom/feature/lsp::lsp-session-diagnostic-table session)))))
        (expect (lsp-diagnostic-message diagnostic)
                :to-equal (format nil "Error~C" (code-char #xfffd)))
        (expect (lsp-diagnostic-source diagnostic)
                :to-equal (format nil "server~C" (code-char #xfffd)))))))

(describe
  "LSP server requests (WP7)"
  (it "answers each immediate server method once with the original ID"
    (%with-fake-lsp-session ((transport session) :root-uri "file:///tmp/wp7")
      (dolist (case '((0 "workspace/configuration" "{\"items\":[{},{}]}" )
                      ("folders" "workspace/workspaceFolders" "{}")
                      (2 "window/workDoneProgress/create" "{\"token\":1}")
                      (3 "client/registerCapability"
                         "{\"registrations\":[{\"id\":\"watch\",\"method\":\"workspace/didChangeWatchedFiles\",\"registerOptions\":{}}]}")
                      (4 "client/unregisterCapability"
                         "{\"unregisterations\":[{\"id\":\"watch\",\"method\":\"workspace/didChangeWatchedFiles\"}]}")
                      ("unknown" "workspace/unknown" "{}")))
        (destructuring-bind (id method params) case
          (%wp7-request transport session id method params)
          (let ((response (%wp7-response transport id)))
            (expect (gethash "jsonrpc" response) :to-equal "2.0")
            (cond
              ((equal id 0)
               (expect (gethash "result" response)
                       :to-equal (list json-kit:+json-null+ json-kit:+json-null+)))
              ((equal id "folders")
               (expect (json-kit:stringify (gethash "result" response))
                       :to-equal
                       (json-kit:stringify
                        (gethash "workspaceFolders"
                                 (%parse-lsp-json
                                  (json-kit:stringify
                                   (loom/feature/lsp::%lsp-initialize-params session)))))))
              ((equal id "unknown")
               (expect (gethash "code" (gethash "error" response)) :to-equal -32601)
               (expect (gethash "message" (gethash "error" response))
                       :to-equal "Method not found"))
              (t (expect (gethash "result" response) :to-be json-kit:+json-null+))))))
      (expect (lsp-session-last-error session) :to-be nil)
      (expect (%fake-sent-in-order transport) :to-have-length 6)))

  (it "records and removes dynamic registrations on the receiving session"
    (%with-fake-lsp-session ((transport session))
      (%wp7-request transport session "register" "client/registerCapability"
                    "{\"registrations\":[{\"id\":\"watch\",\"method\":\"workspace/didChangeWatchedFiles\",\"registerOptions\":{\"marker\":42}}]}")
      (let ((registration
              (gethash "watch" (loom/feature/lsp::lsp-session-registrations session))))
        (expect (gethash "method" registration)
                :to-equal "workspace/didChangeWatchedFiles")
        (expect (gethash "marker" (gethash "registerOptions" registration)) :to-equal 42))
      (%wp7-request transport session "unregister" "client/unregisterCapability"
                    "{\"unregisterations\":[{\"id\":\"watch\",\"method\":\"workspace/didChangeWatchedFiles\"}]}")
      (expect (hash-table-count (loom/feature/lsp::lsp-session-registrations session))
              :to-equal 0)))

  (it "returns null without a workspace and an empty array for no configuration items"
    (%with-fake-lsp-session ((transport session))
      (%wp7-request transport session 1 "workspace/workspaceFolders")
      (expect (gethash "result" (%wp7-response transport 1)) :to-be json-kit:+json-null+)
      (%wp7-request transport session 2 "workspace/configuration" "{\"items\":[]}")
      (expect (search "\"result\":[]" (second (%fake-sent-in-order transport)))
              :to-be-truthy)))

  (it "routes requests before colliding initialize response IDs"
    (%with-started-fake-lsp-session ((transport session))
      (%wp7-request transport session 1 "window/workDoneProgress/create")
      (expect (gethash "result" (%wp7-response transport 1)) :to-be json-kit:+json-null+)
      (expect (lsp-session-initialized-p session) :to-be nil)
      (%fake-push-initialize-response transport)
      (%wp7-frame session)
      (expect (lsp-session-initialized-p session) :to-be-truthy)))

  (it "logs a sanitized unknown method without changing the echo line"
    (%with-lsp-minibuffer-state (minibuffer "")
      (let ((loom/core/minibuffer::*message-sinks* nil)
            (received nil))
        (loom/core/minibuffer:register-message-sink
         :wp7/test (lambda (text) (push text received)))
        (minibuffer-message minibuffer "Keep echo")
        (setf received nil)
        (%with-fake-lsp-session ((transport session))
          (%wp7-request transport session 7
                        (format nil "unknown~C~C~C" #\Escape (code-char 127) #\Tab))
          (expect received
                  :to-equal
                  (list (format nil "lsp: unhandled server request unknown~C~C~C"
                                (code-char #xfffd) (code-char #xfffd) #\Tab)))
          (expect (minibuffer-message-string minibuffer) :to-equal "Keep echo")
          (%wp7-response transport 7)))))

  (it "offers sanitized titles and returns the unmodified selected action"
    (%with-lsp-minibuffer-state (minibuffer "")
      (%with-fake-lsp-session ((transport session))
        (%wp7-request transport session "choose" "window/showMessageRequest"
                      "{\"message\":\"Choose\\u001b\",\"actions\":[{\"title\":\"Run\\u001b\",\"data\":42},{\"title\":\"Stop\"}]}")
        (expect (minibuffer-active-p minibuffer) :to-be-truthy)
        (expect (search (string (code-char #xfffd))
                        (minibuffer-prompt-string minibuffer)) :to-be-truthy)
        (%wp7-key minibuffer :tab)
        (expect (loom/core/minibuffer:minibuffer-completion-candidates minibuffer)
                :to-equal (list (format nil "Run~C" (code-char #xfffd)) "Stop"))
        (%wp7-type minibuffer (format nil "Run~C" (code-char #xfffd)))
        (%wp7-key minibuffer :enter)
        (let ((action (gethash "result" (%wp7-response transport "choose"))))
          (expect (gethash "title" action) :to-equal (format nil "Run~C" #\Escape))
          (expect (gethash "data" action) :to-equal 42))
        (%wp7-frame session)
        (expect (%fake-sent-in-order transport) :to-have-length 1))))

  (it "queues prompts in order and answers C-g with null once"
    (%with-lsp-minibuffer-state (minibuffer "")
      (%with-fake-lsp-session ((transport session))
        (minibuffer-activate minibuffer "Existing: ")
        (%wp7-request transport session 10 "window/showMessageRequest"
                      "{\"message\":\"First\",\"actions\":[{\"title\":\"Yes\"}]}")
        (%wp7-request transport session 11 "window/showMessageRequest"
                      "{\"message\":\"Second\",\"actions\":[{\"title\":\"No\"}]}")
        (expect (minibuffer-prompt-string minibuffer) :to-equal "Existing: ")
        (expect (%fake-sent-in-order transport) :to-have-length 0)
        (%wp7-key minibuffer :enter)
        (%wp7-frame session)
        (expect (search "First" (minibuffer-prompt-string minibuffer)) :to-be-truthy)
        (%wp7-key minibuffer :control-g)
        (expect (gethash "result" (%wp7-response transport 10)) :to-be json-kit:+json-null+)
        (%wp7-frame session)
        (expect (search "Second" (minibuffer-prompt-string minibuffer)) :to-be-truthy)
        (%wp7-key minibuffer :control-g)
        (expect (gethash "result" (%wp7-response transport 11)) :to-be json-kit:+json-null+)
        (%wp7-frame session)
        (expect (minibuffer-active-p minibuffer) :to-be nil)
        (expect (%fake-sent-in-order transport) :to-have-length 2))))

  (it "waits through an existing prompt's continuation"
    (%with-lsp-minibuffer-state (minibuffer "")
      (%with-fake-lsp-session ((transport session))
        (minibuffer-activate minibuffer "Original: "
                             :on-confirm
                             (lambda (input)
                               (declare (ignore input))
                               (minibuffer-activate minibuffer "Continuation: ")))
        (%wp7-request transport session 12 "window/showMessageRequest"
                      "{\"message\":\"Queued\",\"actions\":[{\"title\":\"Yes\"}]}")
        (%wp7-key minibuffer :enter)
        (%wp7-frame session)
        (expect (minibuffer-prompt-string minibuffer) :to-equal "Continuation: ")
        (%wp7-key minibuffer :control-g)
        (%wp7-frame session)
        (expect (search "Queued" (minibuffer-prompt-string minibuffer)) :to-be-truthy)
        (%wp7-key minibuffer :control-g)
        (%wp7-response transport 12))))

  (it "drops queued and active prompts when their session ends"
    (%with-lsp-minibuffer-state (minibuffer "")
      (%with-fake-lsp-session ((transport session))
        (minibuffer-activate minibuffer "Existing: ")
        (%wp7-request transport session 13 "window/showMessageRequest"
                      "{\"message\":\"Discard\",\"actions\":[{\"title\":\"Yes\"}]}")
        (lsp-session-stop session :timeout 0)
        (expect (loom/feature/lsp::lsp-session-server-request-queue session) :to-be nil)
        (expect (minibuffer-prompt-string minibuffer) :to-equal "Existing: ")
        (%wp7-key minibuffer :enter)
        (%wp7-frame session)
        (expect (minibuffer-active-p minibuffer) :to-be nil)))
    (%with-lsp-minibuffer-state (minibuffer "")
      (%with-fake-lsp-session ((transport session))
        (%wp7-request transport session 14 "window/showMessageRequest"
                      "{\"message\":\"Active\",\"actions\":[{\"title\":\"Yes\"}]}")
        (expect (minibuffer-active-p minibuffer) :to-be-truthy)
        (lsp-session-stop session :timeout 0)
        (expect (minibuffer-active-p minibuffer) :to-be nil))))

  (it "replaces every C0/C1 control except TAB before display"
    (%with-lsp-minibuffer-state (minibuffer "")
      (%with-fake-lsp-session ((transport session))
        (let* ((controls (coerce (append (loop for code below 32 collect (code-char code))
                                         (loop for code from 127 to 159 collect (code-char code)))
                                 'string))
               (expected (map 'string (lambda (character)
                                        (if (char= character #\Tab) character (code-char #xfffd)))
                              controls)))
          (%wp7-request transport session 15 "window/showMessageRequest"
                        (json-kit:stringify
                         (json-kit:make-json-object
                          (list (cons "message" controls)
                                (cons "actions" (vector (json-kit:make-json-object
                                                         (list (cons "title" controls)))))))))
          (expect (search expected (minibuffer-prompt-string minibuffer)) :to-be-truthy)
          (%wp7-key minibuffer :tab)
          (expect (loom/core/minibuffer:minibuffer-completion-candidates minibuffer)
                  :to-equal (list expected))
          (%wp7-key minibuffer :control-g)
          (%wp7-response transport 15))))))

(describe
  "Messages-only public API (WP7)"
  (it "notifies message sinks without changing an active prompt or echo"
    (let ((loom/core/minibuffer::*message-sinks* nil)
          (minibuffer (make-minibuffer))
          (received nil))
      (loom/core/minibuffer:register-message-sink
       :wp7/messages (lambda (text) (push text received)))
      (minibuffer-activate minibuffer "Existing: ")
      (minibuffer-message minibuffer "Keep echo")
      (setf received nil)
      (loom/core/minibuffer:minibuffer-log-message "Only log")
      (expect received :to-equal (list "Only log"))
      (expect (minibuffer-message-string minibuffer) :to-equal "Keep echo")
      (expect (minibuffer-prompt-string minibuffer) :to-equal "Existing: ")
      (expect (nth-value 1 (find-symbol "MINIBUFFER-LOG-MESSAGE" :loom/core/minibuffer))
              :to-be :external))))

(describe
  "LSP server request boundary values (WP7)"
  (it "answers absent and empty actions immediately without opening a prompt"
    (%with-lsp-minibuffer-state (minibuffer "")
      (%with-fake-lsp-session ((transport session))
        (%wp7-request transport session 20 "window/showMessageRequest"
                      "{\"message\":\"Notice\"}")
        (%wp7-request transport session 21 "window/showMessageRequest"
                      "{\"message\":\"Notice\",\"actions\":[]}")
        (expect (minibuffer-active-p minibuffer) :to-be nil)
        (expect (gethash "result" (%wp7-response transport 20)) :to-be json-kit:+json-null+)
        (expect (gethash "result" (%wp7-response transport 21)) :to-be json-kit:+json-null+)
        (expect (%fake-sent-in-order transport) :to-have-length 2))))

  (it "preserves null IDs and distinguishes string IDs from numeric IDs"
    (%with-fake-lsp-session ((transport session))
      (dolist (id (list json-kit:+json-null+ 22 "22"))
        (%wp7-request transport session id "window/workDoneProgress/create")
        (expect (gethash "result" (%wp7-response transport id)) :to-be json-kit:+json-null+))
      (expect (%fake-sent-in-order transport) :to-have-length 3)))

  (it "preserves JSON false inside the selected original action"
    (%with-lsp-minibuffer-state (minibuffer "")
      (%with-fake-lsp-session ((transport session))
        (%fake-push-and-drain
         transport session
         "{\"jsonrpc\":\"2.0\",\"id\":23,\"method\":\"window/showMessageRequest\",\"params\":{\"message\":\"Choose\",\"actions\":[{\"title\":\"Yes\",\"data\":{\"flag\":false,\"items\":[]}}]}}")
        (%wp7-frame session)
        (%wp7-type minibuffer "Yes")
        (%wp7-key minibuffer :enter)
        (%wp7-response transport 23)
        (expect (search "\"flag\":false" (first (%fake-sent-in-order transport))) :to-be-truthy)
        (expect (search "\"items\":[]" (first (%fake-sent-in-order transport))) :to-be-truthy)))))
