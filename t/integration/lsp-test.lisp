(in-package #:loom/test)

(defclass %fake-lsp-transport ()
  ((sent :initform nil :accessor %fake-sent)
   (incoming :initform nil :accessor %fake-incoming)
   (closed-p :initform nil :accessor %fake-closed-p)))

(defmethod loom::lsp-transport-send ((transport %fake-lsp-transport) json)
  (push json (%fake-sent transport)))

(defmethod loom::lsp-transport-receive ((transport %fake-lsp-transport))
  (when (%fake-incoming transport)
    (pop (%fake-incoming transport))))

(defmethod loom::lsp-transport-close ((transport %fake-lsp-transport))
  (setf (%fake-closed-p transport) t)
  transport)

(defun %fake-push-incoming (transport json)
  (setf (%fake-incoming transport)
        (append (%fake-incoming transport) (list json))))

(defun %fake-sent-in-order (transport)
  (reverse (%fake-sent transport)))

(describe
  "LSP framing"
  (it "frames and decodes UTF-8 JSON"
    (let* ((json "{\"jsonrpc\":\"2.0\",\"result\":\"日本語\"}")
           (frame (loom::loom-lsp-frame-encode json)))
      (multiple-value-bind (decoded consumed status)
          (loom::loom-lsp-frame-decode frame)
        (expect status :to-be :complete)
        (expect decoded :to-equal json)
        (expect consumed :to-equal (length frame))))
    (let* ((json "{\"ok\":true}")
           (frame (loom::loom-lsp-frame-encode json))
           (partial (subseq frame 0 (floor (length frame) 2))))
      (multiple-value-bind (decoded consumed status)
          (loom::loom-lsp-frame-decode partial)
        (expect decoded :to-be nil)
        (expect consumed :to-equal 0)
        (expect status :to-be :incomplete)))))

(describe
  "LSP session"
  (it "initializes through a transport seam"
    (let* ((transport (make-instance '%fake-lsp-transport))
           (session (make-lsp-session :transport transport
                                      :root-uri "file:///tmp")))
      (lsp-session-start session)
      (let* ((sent (%fake-sent-in-order transport))
             (request (loom::loom-json-parse (first sent))))
        (expect (loom::loom-json-object-get request "method")
                :to-equal "initialize")
        (expect (loom::loom-json-object-get request "id")
                :to-equal 1))
      (%fake-push-incoming
       transport
       "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{}}")
      (lsp-session-drain session)
      (expect (lsp-session-initialized-p session) :to-be-truthy)
      (let* ((messages (%fake-sent-in-order transport))
             (initialized (loom::loom-json-parse (second messages))))
        (expect (loom::loom-json-object-get initialized "method")
                :to-equal "initialized"))
      (lsp-session-stop session)
      (expect (%fake-closed-p transport) :to-be-truthy)))
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
             (open (loom::loom-json-parse (third messages)))
             (text-document
               (loom::loom-json-object-get open "params" nil)))
        (expect (loom::loom-json-object-get open "method")
                :to-equal "textDocument/didOpen")
        (expect (loom::loom-json-object-get text-document "textDocument" nil)
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
  (it "round-trips a framed message through a child process"
    (let ((process (loom::make-lsp-process "cat"))
          (received nil))
      (unwind-protect
           (progn
             (loom::lsp-transport-send process "{\"ok\":true}")
             (loop repeat 200
                   do (setf received
                            (loom::lsp-transport-receive process))
                      (when received (return))
                      (sleep 0.01))
             (expect received :to-equal "{\"ok\":true}"))
        (loom::lsp-transport-close process)))))

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
               (loom::lsp-diagnostics)
               (let ((diagnostics-buffer (%selected-test-buffer)))
                 (expect (buffer-name diagnostics-buffer)
                         :to-equal "*Loom-Diagnostics*")
                 (expect (buffer-text diagnostics-buffer)
                         :to-contain "bad")
                 (expect (loom::%minibuffer-message
                          (editor-state-minibuffer state))
                         :to-equal "LSP diagnostics refreshed."))))
        (lsp-session-stop session)))))
