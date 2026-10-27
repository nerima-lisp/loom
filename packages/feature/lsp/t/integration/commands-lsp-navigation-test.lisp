(in-package #:loom/test)
(describe
  "LSP hover at point"
  (it
    "reports the missing session without sending a request"
    (let ((*editor-state* (%lsp-navigation-state)))
      (loom/feature/lsp:lsp-hover-at-point)
      (expect (minibuffer-message-string
               (editor-state-minibuffer *editor-state*))
              :to-equal "No LSP session for this buffer")))

  (it
    "requires a file-backed buffer"
    (%with-lsp-navigation (transport session buffer :path nil)
      (let ((before (length (%fake-sent-in-order transport))))
        (loom/feature/lsp:lsp-hover-at-point)
        (expect (minibuffer-message-string
                 (editor-state-minibuffer *editor-state*))
                :to-equal "No LSP session for this buffer")
        (expect (length (%fake-sent-in-order transport)) :to-equal before))))

  (it
    "does not request hover without the advertised capability"
    (%with-lsp-navigation (transport session buffer :capabilities "{}")
      (let ((before (length (%fake-sent-in-order transport))))
        (loom/feature/lsp:lsp-hover-at-point)
        (expect (minibuffer-message-string
                 (editor-state-minibuffer *editor-state*))
                :to-equal "Server does not provide hover")
        (expect (length (%fake-sent-in-order transport)) :to-equal before))))

  (it
    "sends the hover method with the UTF-16 document position"
    (%with-lsp-navigation (transport session buffer
                           :content (format nil "~C fo" (code-char #x1f600)))
      (buffer-set-point buffer 0 4)
      (loom/feature/lsp:lsp-hover-at-point)
      (expect (%lsp-last-request-method transport)
              :to-equal "textDocument/hover")
      (let* ((request (%parse-lsp-json
                       (car (last (%fake-sent-in-order transport)))))
             (params (gethash "params" request))
             (document (gethash "textDocument" params))
             (position (gethash "position" params)))
        (expect (gethash "uri" document)
                :to-equal (lsp-path-uri (buffer-path buffer)))
        (expect (gethash "line" position) :to-equal 0)
        (expect (gethash "character" position) :to-equal 5))
      (%fake-push-and-drain
       transport session
       (format nil "{\"jsonrpc\":\"2.0\",\"id\":~D,\"result\":null}"
               (%lsp-last-request-id transport)))))

  (it
    "renders MarkupContent without dropping its value"
    (%with-lsp-navigation (transport session buffer)
      (loom/feature/lsp:lsp-hover-at-point)
      (%fake-push-and-drain
       transport session
       (format nil
               "{\"jsonrpc\":\"2.0\",\"id\":~D,\"result\":{\"contents\":{\"kind\":\"markdown\",\"value\":\"**foo**\\nmore\"}}}"
               (%lsp-last-request-id transport)))
      (expect (minibuffer-message-string
               (editor-state-minibuffer *editor-state*))
              :to-equal (format nil "**foo**~%more"))))

  (it
    "renders MarkedString values from strings, objects, and arrays"
    (%with-lsp-navigation (transport session buffer)
      (loom/feature/lsp:lsp-hover-at-point)
      (%fake-push-and-drain
       transport session
       (format nil
               "{\"jsonrpc\":\"2.0\",\"id\":~D,\"result\":{\"contents\":[\"plain\",{\"language\":\"lisp\",\"value\":\"(defun foo () 1)\"}]}}"
               (%lsp-last-request-id transport)))
      (expect (minibuffer-message-string
               (editor-state-minibuffer *editor-state*))
              :to-equal (format nil "plain~%(defun foo () 1)"))))

  (it
    "reports an empty hover response"
    (%with-lsp-navigation (transport session buffer)
      (loom/feature/lsp:lsp-hover-at-point)
      (%fake-push-and-drain
       transport session
       (format nil "{\"jsonrpc\":\"2.0\",\"id\":~D,\"result\":null}"
               (%lsp-last-request-id transport)))
      (expect (minibuffer-message-string
               (editor-state-minibuffer *editor-state*))
              :to-equal "No hover information")))

  (it
    "reports a server error instead of leaving the request hanging"
    (%with-lsp-navigation (transport session buffer)
      (loom/feature/lsp:lsp-hover-at-point)
      (%fake-push-and-drain
       transport session
       (format nil
               "{\"jsonrpc\":\"2.0\",\"id\":~D,\"error\":{\"code\":-32603,\"message\":\"boom\"}}"
               (%lsp-last-request-id transport)))
      (expect (minibuffer-message-string
               (editor-state-minibuffer *editor-state*))
              :to-equal "Hover failed: boom"))))

(describe
  "LSP completion at point"
  (it
    "reports the missing session without sending a request"
    (let ((*editor-state* (%lsp-navigation-state)))
      (loom/feature/lsp:lsp-completion-at-point)
      (expect (minibuffer-message-string
               (editor-state-minibuffer *editor-state*))
              :to-equal "No LSP session for this buffer")))

  (it
    "reports no session for a buffer without a file path"
    (%with-lsp-navigation (transport session buffer :path nil)
      (let ((before (length (%fake-sent-in-order transport))))
        (loom/feature/lsp:lsp-completion-at-point)
        (expect (minibuffer-message-string
                 (editor-state-minibuffer *editor-state*))
                :to-equal "No LSP session for this buffer")
        (expect (length (%fake-sent-in-order transport)) :to-equal before))))

  (it
    "drains a pending initialization before sending a completion request"
    (let* ((*editor-state* (%lsp-navigation-state))
           (transport (make-instance '%fake-lsp-transport))
           (session (make-lsp-session :transport transport)))
      (unwind-protect
           (progn
             (%lsp-test-register-session *editor-state* (%selected-test-buffer) session)
             (lsp-session-start session)
             (%fake-push-initialize-response
              transport
              +lsp-navigation-capabilities+)
             (lsp-completion-at-point)
             (expect (lsp-session-initialized-p session) :to-be-truthy)
             (expect (%lsp-last-request-method transport)
                     :to-equal "textDocument/completion"))
        (lsp-session-stop session))))

  (it
    "says so and sends nothing when the server does not provide completion"
    (%with-lsp-navigation (transport session buffer :capabilities "{}")
      (let ((before (length (%fake-sent-in-order transport))))
        (loom/feature/lsp:lsp-completion-at-point)
        (expect (minibuffer-message-string
                 (editor-state-minibuffer *editor-state*))
                :to-equal "Server does not provide completion")
        (expect (length (%fake-sent-in-order transport)) :to-equal before)
        (expect (editor-state-completion *editor-state*) :to-be nil))))

  (it
    "sends textDocument/completion and shows the reply as a popup"
    (%with-lsp-navigation (transport session buffer)
      (buffer-set-point buffer 0 3)
      (loom/feature/lsp:lsp-completion-at-point)
      (expect (%lsp-last-request-method transport)
              :to-equal "textDocument/completion")
      (%fake-push-and-drain
       transport session
       (format nil
               "{\"jsonrpc\":\"2.0\",\"id\":~D,\"result\":[{\"label\":\"foobar\"},{\"label\":\"foobaz\"}]}"
               (%lsp-last-request-id transport)))
      (let ((completion (editor-state-completion *editor-state*)))
        (expect completion :to-be-truthy)
        (expect (mapcar #'editor-completion-item-label
                        (editor-completion-items completion))
                :to-equal '("foobar" "foobaz"))
        (expect (editor-completion-column completion) :to-equal 0))))

  (it
    "anchors the popup at the start of the symbol being completed"
    (%with-lsp-navigation (transport session buffer :content "(list foo")
      (buffer-set-point buffer 0 9)
      (loom/feature/lsp:lsp-completion-at-point)
      (%fake-push-and-drain
       transport session
       (format nil "{\"jsonrpc\":\"2.0\",\"id\":~D,\"result\":[{\"label\":\"foobar\"}]}"
               (%lsp-last-request-id transport)))
      (expect (editor-completion-column
               (editor-state-completion *editor-state*))
              :to-equal 6)))

  (it
    "sends UTF-16 completion positions while preserving the popup anchor"
    (%with-lsp-navigation (transport session buffer
                           :content (format nil "~C fo" (code-char #x1f600)))
      (buffer-set-point buffer 0 4)
      (lsp-completion-at-point)
      (let* ((request (%parse-lsp-json
                       (car (last (%fake-sent-in-order transport)))))
             (position (gethash "position" (gethash "params" request))))
        (expect (gethash "character" position) :to-equal 5))
      (%fake-push-and-drain
       transport session
       (format nil "{\"jsonrpc\":\"2.0\",\"id\":~D,\"result\":[{\"label\":\"foobar\"}]}"
               (%lsp-last-request-id transport)))
      (expect (editor-completion-column
               (editor-state-completion *editor-state*))
              :to-equal 2)))

  (it
    "reports an empty reply rather than opening an empty popup"
    (%with-lsp-navigation (transport session buffer)
      (loom/feature/lsp:lsp-completion-at-point)
      (%fake-push-and-drain
       transport session
       (format nil "{\"jsonrpc\":\"2.0\",\"id\":~D,\"result\":[]}"
               (%lsp-last-request-id transport)))
      (expect (editor-state-completion *editor-state*) :to-be nil)
      (expect (minibuffer-message-string
               (editor-state-minibuffer *editor-state*))
              :to-equal "No completions")))

  (it
    "reports a server error instead of leaving the request hanging"
    (%with-lsp-navigation (transport session buffer)
      (loom/feature/lsp:lsp-completion-at-point)
      (%fake-push-and-drain
       transport session
       (format nil
               "{\"jsonrpc\":\"2.0\",\"id\":~D,\"error\":{\"code\":-32603,\"message\":\"boom\"}}"
               (%lsp-last-request-id transport)))
      (expect (minibuffer-message-string
               (editor-state-minibuffer *editor-state*))
              :to-equal "Completion failed: boom")
      (expect (editor-state-completion *editor-state*) :to-be nil))))
