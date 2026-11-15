(in-package #:loom/test)

(defclass %wp7-revision-transport (%fake-lsp-transport)
  ((attempts :initform 0 :accessor %wp7-revision-attempts)
   (fail-after-write :initform nil :accessor %wp7-revision-fail-after-write)))

(defmethod loom/feature/lsp::lsp-transport-send ((transport %wp7-revision-transport) json)
  (incf (%wp7-revision-attempts transport))
  (when (%wp7-revision-fail-after-write transport)
    (push json (%fake-sent transport))
    (setf (%wp7-revision-fail-after-write transport) nil)
    (error "partial server response write"))
  (call-next-method))

(defun %wp7-revision-raw-request (id method params)
  (format nil "{\"jsonrpc\":\"2.0\",\"id\":~A,\"method\":~A,\"params\":~A}"
          (json-kit:stringify id) (json-kit:stringify method) params))

(defun %wp7-revision-controls-p (text)
  (some (lambda (character)
          (let ((code (char-code character)))
            (or (and (< code 32) (/= code 9)) (<= 127 code 159))))
        text))

(describe
  "LSP server request prompt ownership revision"
  (it "waits through the actual rename command's initialization before showing a server prompt"
    (%with-lsp-file-minibuffer-state (minibuffer buffer #P"/tmp/wp7-revision.lisp" "old")
      (%with-started-fake-lsp-session ((transport session))
        (%lsp-test-register-session-for-buffer buffer session)
        (%fake-push-incoming
         transport
         (%wp7-revision-raw-request
          "server-choice" "window/showMessageRequest"
          "{\"message\":\"Server choice\",\"actions\":[{\"title\":\"Allow\"}]}"))
        (%fake-push-initialize-response transport "{\"capabilities\":{\"renameProvider\":true}}")
        (loom/feature/lsp:lsp-rename)
        (expect (minibuffer-prompt-string minibuffer) :to-equal "Rename to: ")
        (%wp7-type minibuffer "new")
        (%wp7-key minibuffer :enter)
        (let ((rename
                (find "textDocument/rename"
                      (mapcar #'%parse-lsp-json (%fake-sent-in-order transport))
                      :test #'equal :key (lambda (message) (gethash "method" message)))))
          (expect rename :to-be-truthy)
          (%fake-push-and-drain
           transport session
           (format nil "{\"jsonrpc\":\"2.0\",\"id\":~A,\"result\":null}"
                   (gethash "id" rename))))
        (lsp-refresh-editor-state *editor-state*)
        (expect (minibuffer-prompt-string minibuffer) :to-equal "Server choice: ")
        (%wp7-key minibuffer :control-g)
        (expect (gethash "result" (%wp7-response transport "server-choice"))
                :to-be json-kit:+json-null+))))

  (it "queues during drain and starts prompts only from the editor frame"
    (%with-lsp-minibuffer-state (minibuffer "")
      (%with-fake-lsp-session ((transport session))
        (%fake-push-and-drain
         transport session
         (%wp7-revision-raw-request
          100 "window/showMessageRequest"
          "{\"message\":\"Frame only\",\"actions\":[{\"title\":\"Allow\"}]}"))
        (expect (minibuffer-active-p minibuffer) :to-be nil)
        (%wp7-frame session)
        (expect (minibuffer-prompt-string minibuffer) :to-equal "Frame only: ")
        (%wp7-key minibuffer :control-g)
        (%wp7-response transport 100))))

  (it "does not close a replacement prompt with identical text when the session stops"
    (%with-lsp-minibuffer-state (minibuffer "")
      (%with-fake-lsp-session ((transport session))
        (%wp7-request transport session 101 "window/showMessageRequest"
                      "{\"message\":\"Same prompt\",\"actions\":[{\"title\":\"Allow\"}]}")
        (let ((same-prompt (minibuffer-prompt-string minibuffer))
              (confirmed nil))
          (minibuffer-activate minibuffer same-prompt
                               :on-confirm (lambda (input) (setf confirmed input)))
          (lsp-session-stop session :timeout 0)
          (expect (minibuffer-active-p minibuffer) :to-be t)
          (expect (minibuffer-prompt-string minibuffer) :to-equal "Same prompt: ")
          (%wp7-type minibuffer "kept")
          (%wp7-key minibuffer :enter)
          (expect confirmed :to-equal "kept")))))

  (it "does not open a queued server prompt while stopping an initialized session"
    (%with-lsp-minibuffer-state (minibuffer "")
      (%with-initialized-fake-lsp-session ((transport session))
        (minibuffer-activate minibuffer "Existing: ")
        (%wp7-request transport session 102 "window/showMessageRequest"
                      "{\"message\":\"Discard\",\"actions\":[{\"title\":\"Allow\"}]}")
        (loom/core/minibuffer:minibuffer-deactivate minibuffer)
        (lsp-session-stop session :timeout 0)
        (expect (minibuffer-active-p minibuffer) :to-be nil)
        (expect (loom/feature/lsp::lsp-session-server-request-queue session) :to-be nil)))))

(describe
  "LSP malformed server requests revision"
  (it "rejects requests missing required params while allowing optional params to be absent"
    (%with-fake-lsp-session ((transport session))
      (loop for method in '("client/registerCapability" "client/unregisterCapability"
                            "workspace/configuration" "window/showMessageRequest")
            for id from 180
            do (%fake-push-and-drain
                transport session
                (format nil "{\"jsonrpc\":\"2.0\",\"id\":~D,\"method\":~A}"
                        id (json-kit:stringify method)))
               (expect (gethash "code" (gethash "error" (%wp7-response transport id)))
                       :to-equal -32602))
      (%fake-push-and-drain transport session
                            "{\"jsonrpc\":\"2.0\",\"id\":184,\"method\":\"workspace/workspaceFolders\"}")
      (expect (gethash "result" (%wp7-response transport 184)) :to-be json-kit:+json-null+)
      (%fake-push-and-drain transport session
                            "{\"jsonrpc\":\"2.0\",\"id\":185,\"method\":\"unknown/method\"}")
      (expect (gethash "code" (gethash "error" (%wp7-response transport 185))) :to-equal -32601)))

  (it "returns one Invalid params response and processes the following valid request"
    (%with-fake-lsp-session ((transport session))
      (loop for (method params) in
            '((42 "{}")
              ("workspace/configuration" "false")
              ("workspace/configuration" "null")
              ("workspace/configuration" "[]")
              ("workspace/configuration" "\"params\"")
              ("workspace/configuration" "{}")
              ("workspace/configuration" "{\"items\":false}")
              ("workspace/configuration" "{\"items\":null}")
              ("workspace/configuration" "{\"items\":\"items\"}")
              ("workspace/configuration" "{\"items\":{}}")
              ("client/registerCapability" "{}")
              ("client/registerCapability" "{\"registrations\":\"items\"}")
              ("client/registerCapability" "{\"registrations\":[1]}")
              ("client/registerCapability" "{\"registrations\":[{\"id\":1,\"method\":\"x\"}]}")
              ("client/registerCapability" "{\"registrations\":[{\"id\":\"x\",\"method\":null}]}")
              ("client/unregisterCapability" "{\"unregisterations\":false}")
              ("client/unregisterCapability" "{\"unregisterations\":[null]}")
              ("window/showMessageRequest" "{}")
              ("window/showMessageRequest" "{\"message\":null}")
              ("window/showMessageRequest" "{\"message\":\"m\",\"actions\":false}")
              ("window/showMessageRequest" "{\"message\":\"m\",\"actions\":null}")
              ("window/showMessageRequest" "{\"message\":\"m\",\"actions\":\"items\"}")
              ("window/showMessageRequest" "{\"message\":\"m\",\"actions\":{}}")
              ("window/showMessageRequest" "{\"message\":\"m\",\"actions\":[null]}")
              ("window/showMessageRequest" "{\"message\":\"m\",\"actions\":[{}]}")
              ("window/showMessageRequest" "{\"message\":\"m\",\"actions\":[{\"title\":1}]}"))
            for id from 200
            for next-id = (+ id 1000)
            do (%fake-push-incoming transport (%wp7-revision-raw-request id method params))
               (%fake-push-incoming transport
                                    (%wp7-revision-raw-request next-id "window/workDoneProgress/create" "{}"))
               (%fake-push-publish-diagnostics transport
                                               (format nil "/tmp/wp7-invalid-~D" id) "[]")
               (lsp-session-drain session)
               (expect (nth-value 1
                                  (gethash (lsp-path-uri (format nil "/tmp/wp7-invalid-~D" id))
                                           (loom/feature/lsp::lsp-session-diagnostic-table session)))
                       :to-be t)
               (expect (loom/feature/lsp::lsp-session-server-request-queue session) :to-be nil)
               (expect (gethash "code" (gethash "error" (%wp7-response transport id)))
                       :to-equal -32602)
               (expect (gethash "result" (%wp7-response transport next-id))
                       :to-be json-kit:+json-null+))))

  (it "validates all registration entries before changing session registrations"
    (%with-fake-lsp-session ((transport session))
      (%wp7-request
       transport session 300 "client/registerCapability"
       "{\"registrations\":[{\"id\":\"valid\",\"method\":\"watch\"},{}]}")
      (expect (gethash "code" (gethash "error" (%wp7-response transport 300))) :to-equal -32602)
      (expect (hash-table-count (loom/feature/lsp::lsp-session-registrations session)) :to-equal 0)
      (%wp7-request transport session 301 "client/registerCapability"
                    "{\"registrations\":[{\"id\":\"valid\",\"method\":\"watch\"}]}")
      (%wp7-request transport session 302 "client/unregisterCapability"
                    "{\"unregisterations\":[{\"id\":\"valid\",\"method\":\"watch\"},{}]}")
      (expect (gethash "code" (gethash "error" (%wp7-response transport 302))) :to-equal -32602)
      (expect (gethash "valid" (loom/feature/lsp::lsp-session-registrations session)) :to-be-truthy)))

  (it "reports an internal processing error once and continues draining"
    (let ((loom/core/minibuffer::*message-sinks* nil))
      (loom/core/minibuffer:register-message-sink
       :wp7/internal (lambda (text) (declare (ignore text)) (error "sink unavailable")))
      (%with-fake-lsp-session ((transport session))
        (%fake-push-incoming transport (%wp7-revision-raw-request 303 "unknown/request" "{}"))
        (%fake-push-incoming transport (%wp7-revision-raw-request 304 "window/workDoneProgress/create" "{}"))
        (lsp-session-drain session)
        (expect (gethash "code" (gethash "error" (%wp7-response transport 303))) :to-equal -32603)
        (expect (gethash "result" (%wp7-response transport 304)) :to-be json-kit:+json-null+))))

  (it "does not attempt another response after a partially written response fails"
    (let* ((transport (make-instance '%wp7-revision-transport))
           (session (make-lsp-session :transport transport)))
      (unwind-protect
           (progn
             (setf (%wp7-revision-fail-after-write transport) t)
             (%wp7-request transport session 305 "window/workDoneProgress/create")
             (expect (%wp7-revision-attempts transport) :to-equal 1)
             (%wp7-response transport 305)
             (expect (lsp-session-last-error session) :to-be-truthy))
        (lsp-session-stop session :timeout 0)))))

(describe
  "LSP prompt cancellation transport errors revision"
  (it "closes the prompt and records a sanitized error after a dead server rejects C-g"
    (%with-lsp-minibuffer-state (minibuffer "")
      (let* ((transport (make-instance '%wp7-revision-transport))
             (session (make-lsp-session :transport transport)))
        (unwind-protect
             (progn
               (%wp7-request transport session 400 "window/showMessageRequest"
                             "{\"message\":\"Choose\",\"actions\":[{\"title\":\"Allow\"}]}")
               (expect (minibuffer-active-p minibuffer) :to-be t)
               (setf (%fake-send-error transport)
                     (format nil "dead~C~C~C" #\Escape (code-char 127) (code-char 133)))
               (%wp7-key minibuffer :control-g)
               (expect (minibuffer-active-p minibuffer) :to-be nil)
               (expect (%wp7-revision-attempts transport) :to-equal 1)
               (expect (%fake-sent-in-order transport) :to-have-length 0)
               (expect (lsp-session-last-error session) :to-be-truthy)
               (expect (%wp7-revision-controls-p (lsp-session-last-error session)) :to-be nil))
          (lsp-session-stop session :timeout 0))))))

(describe
  "LSP notice and error display revision"
  (it "records and echoes sanitized notices without actions and returns null once"
    (%with-lsp-minibuffer-state (minibuffer "")
      (let ((loom/core/minibuffer::*message-sinks* nil)
            (received nil))
        (loom/core/minibuffer:register-message-sink :wp7/notice (lambda (text) (push text received)))
        (%with-fake-lsp-session ((transport session))
          (loop for params in '("{\"message\":\"Notice\\u001b\\u007f\\u0085\"}"
                                "{\"message\":\"Notice\\u001b\\u007f\\u0085\",\"actions\":[]}")
                for id from 500
                do (%wp7-request transport session id "window/showMessageRequest" params)
                   (expect (minibuffer-message-string minibuffer)
                           :to-equal (format nil "Notice~C~C~C" (code-char #xfffd) (code-char #xfffd) (code-char #xfffd)))
                   (expect (first received) :to-equal (minibuffer-message-string minibuffer))
                   (expect (minibuffer-active-p minibuffer) :to-be nil)
                   (expect (gethash "result" (%wp7-response transport id)) :to-be json-kit:+json-null+))
          (expect received :to-have-length 2)))))

  (it "sanitizes the startup error before echo and Messages dispatch"
    (%with-lsp-minibuffer-state (minibuffer "")
      (let ((loom/core/minibuffer::*message-sinks* nil)
            (received nil)
            (condition (make-condition 'simple-error :format-control "~A"
                                       :format-arguments (list (format nil "server~C~C~C" #\Escape (code-char 127) (code-char 133))))))
        (loom/core/minibuffer:register-message-sink :wp7/startup (lambda (text) (push text received)))
        (loom/feature/lsp::%lsp-report-start-result minibuffer nil condition)
        (expect (%wp7-revision-controls-p (minibuffer-message-string minibuffer)) :to-be nil)
        (expect received :to-equal (list (minibuffer-message-string minibuffer))))))

  (it "sanitizes transport errors from refresh and shutdown before recording them"
    (%with-lsp-file-minibuffer-state (minibuffer buffer #P"/tmp/wp7-error.lisp" "old")
      (%with-initialized-fake-lsp-session ((transport session))
        (setf (%fake-send-error transport)
              (format nil "server~C~C~C" #\Escape (code-char 127) (code-char 133)))
        (lsp-session-refresh session buffer)
        (expect (lsp-session-last-error session) :to-be-truthy)
        (expect (%wp7-revision-controls-p (lsp-session-last-error session)) :to-be nil)
        (setf (lsp-session-last-error session) nil)
        (loom/feature/lsp::%lsp-request-shutdown session)
        (expect (lsp-session-last-error session) :to-be-truthy)
        (expect (%wp7-revision-controls-p (lsp-session-last-error session)) :to-be nil))))

  (it "sanitizes errors thrown while acknowledging initialize"
    (%with-started-fake-lsp-session ((transport session))
      (setf (%fake-send-error transport)
            (format nil "server~C~C~C" #\Escape (code-char 127) (code-char 133)))
      (%fake-push-initialize-response transport)
      (lsp-session-drain session)
      (expect (lsp-session-last-error session) :to-be-truthy)
      (expect (%wp7-revision-controls-p (lsp-session-last-error session)) :to-be nil))))
