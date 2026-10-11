(in-package #:loom/test)

(describe
  "LSP definition jump"
  (it
    "reports the missing session without sending a request"
    (let ((*editor-state* (%lsp-navigation-state)))
      (loom/feature/lsp:lsp-find-definition)
      (expect (minibuffer-message-string
               (editor-state-minibuffer *editor-state*))
              :to-equal "No LSP session for this buffer")))

  (it
    "reports the missing file path without sending a request"
    (%with-lsp-navigation (transport session buffer)
      (setf (loom::%buffer-path buffer) nil)
      (let ((before (length (%fake-sent-in-order transport))))
        (loom/feature/lsp:lsp-find-definition)
        (expect (minibuffer-message-string
                 (editor-state-minibuffer *editor-state*))
                :to-equal "No LSP session for this buffer")
        (expect (length (%fake-sent-in-order transport)) :to-equal before))))

  (it
    "says so and sends nothing when the server does not provide definitions"
    (%with-lsp-navigation (transport session buffer :capabilities "{}")
      (let ((before (length (%fake-sent-in-order transport))))
        (loom/feature/lsp:lsp-find-definition)
        (expect (minibuffer-message-string
                 (editor-state-minibuffer *editor-state*))
                :to-equal "Server does not provide definitions")
        (expect (length (%fake-sent-in-order transport)) :to-equal before))))

  (it
    "moves point within the same file and returns on a pop"
    (%with-lsp-navigation (transport session buffer
                           :content (format nil "one~%two~%three"))
      (buffer-set-point buffer 2 1)
      (loom/feature/lsp:lsp-find-definition)
      (expect (%lsp-last-request-method transport)
              :to-equal "textDocument/definition")
      (%fake-push-and-drain
       transport session
       (format nil
               "{\"jsonrpc\":\"2.0\",\"id\":~D,\"result\":{\"uri\":\"~A\",\"range\":{\"start\":{\"line\":0,\"character\":2},\"end\":{\"line\":0,\"character\":3}}}}"
               (%lsp-last-request-id transport)
               (lsp-path-uri "/tmp/main.lisp")))
      (expect buffer :to-have-point (cons 0 2))
      (loom/feature/lsp:lsp-pop-definition)
      (expect buffer :to-have-point (cons 2 1))))

  (it
    "converts UTF-16 definition positions and preserves the jump origin"
    (%with-lsp-navigation (transport session buffer
                           :content (format nil "~C foo bar" (code-char #x1f600)))
      (buffer-set-point buffer 0 8)
      (lsp-find-definition)
      (let* ((request (%parse-lsp-json
                       (car (last (%fake-sent-in-order transport)))))
             (position (gethash "position" (gethash "params" request))))
        (expect (gethash "character" position) :to-equal 9))
      (%fake-push-and-drain
       transport session
       (format nil
               "{\"jsonrpc\":\"2.0\",\"id\":~D,\"result\":{\"uri\":\"~A\",\"range\":{\"start\":{\"line\":0,\"character\":7},\"end\":{\"line\":0,\"character\":10}}}}"
               (%lsp-last-request-id transport)
               (lsp-path-uri "/tmp/main.lisp")))
      (expect buffer :to-have-point (cons 0 6))
      (lsp-pop-definition)
      (expect buffer :to-have-point (cons 0 8))))

  (it
    "reports an empty result rather than jumping nowhere"
    (%with-lsp-navigation (transport session buffer)
      (buffer-set-point buffer 0 1)
      (loom/feature/lsp:lsp-find-definition)
      (%fake-push-and-drain
       transport session
       (format nil "{\"jsonrpc\":\"2.0\",\"id\":~D,\"result\":null}"
               (%lsp-last-request-id transport)))
      (expect (minibuffer-message-string
               (editor-state-minibuffer *editor-state*))
              :to-equal "No definition found")
      (expect buffer :to-have-point (cons 0 1))))

  (it
    "reports an error result rather than jumping nowhere"
    (%with-lsp-navigation (transport session buffer)
      (buffer-set-point buffer 0 1)
      (loom/feature/lsp:lsp-find-definition)
      (%fake-push-and-drain
       transport session
       (format nil
               "{\"jsonrpc\":\"2.0\",\"id\":~D,\"error\":{\"code\":-32603,\"message\":\"server failed\"}}"
               (%lsp-last-request-id transport)))
      (expect (minibuffer-message-string
               (editor-state-minibuffer *editor-state*))
              :to-equal "Definition failed: server failed")
      (expect buffer :to-have-point (cons 0 1))))

  (it
    "declines a definition that is not a local file"
    (%with-lsp-navigation (transport session buffer)
      (loom/feature/lsp:lsp-find-definition)
      (%fake-push-and-drain
       transport session
       (format nil
               "{\"jsonrpc\":\"2.0\",\"id\":~D,\"result\":{\"uri\":\"jar:///a.class\",\"range\":{\"start\":{\"line\":0,\"character\":0},\"end\":{\"line\":0,\"character\":1}}}}"
               (%lsp-last-request-id transport)))
      (expect (minibuffer-message-string
               (editor-state-minibuffer *editor-state*))
              :to-equal "Definition is not a local file: jar:///a.class")))

  (it
    "reports a local definition that cannot be opened"
    (host-kit:with-temporary-directory (directory)
      (let ((path (merge-pathnames "missing.lisp" directory)))
        (%with-lsp-navigation (transport session buffer)
          (with-replaced-function
              (loom/feature/file-tree:visit-file (lambda (ignored-path)
                                                    (declare (ignore ignored-path))
                                                    nil))
            (loom/feature/lsp:lsp-find-definition)
            (%fake-push-and-drain
             transport session
             (format nil
                     "{\"jsonrpc\":\"2.0\",\"id\":~D,\"result\":{\"uri\":\"~A\",\"range\":{\"start\":{\"line\":0,\"character\":0},\"end\":{\"line\":0,\"character\":1}}}}"
                     (%lsp-last-request-id transport)
                     (lsp-path-uri path)))
            (expect (minibuffer-message-string
                     (editor-state-minibuffer *editor-state*))
                    :to-equal (format nil "Cannot open ~A" path)))))))

  (it
    "reports having nothing to return to"
    (%with-lsp-navigation (transport session buffer)
      (loom/feature/lsp:lsp-pop-definition)
      (expect (minibuffer-message-string
               (editor-state-minibuffer *editor-state*))
              :to-equal "No jump to return from"))))

(describe
  "LSP navigation synchronization"
  (it-each
      (("completion" loom/feature/lsp:lsp-completion-at-point "textDocument/completion")
       ("definition" loom/feature/lsp:lsp-find-definition "textDocument/definition"))
      "opens the document before requesting ~A" (label command method)
    (declare (ignore label))
    (%with-lsp-navigation (transport session buffer)
      (funcall command)
      (expect (mapcar (lambda (json) (gethash "method" (%parse-lsp-json json)))
                      (%fake-sent-in-order transport))
              :to-equal (list "initialize" "initialized" "textDocument/didOpen" method))
      (let ((document (gethash "textDocument"
                               (gethash "params" (%fake-sent-message transport 2)))))
        (expect (gethash "uri" document) :to-equal (lsp-path-uri "/tmp/main.lisp"))
        (expect (gethash "text" document) :to-equal "foo")
        (expect (gethash "version" document) :to-equal 1))))

  (it-each
      (("completion" loom/feature/lsp:lsp-completion-at-point "textDocument/completion")
       ("definition" loom/feature/lsp:lsp-find-definition "textDocument/definition"))
      "sends edits before requesting ~A without resending unchanged text" (label command method)
    (declare (ignore label))
    (%with-lsp-navigation (transport session buffer)
      (lsp-session-sync-buffer session buffer)
      (buffer-insert-string buffer "!")
      (funcall command)
      (expect (mapcar (lambda (json) (gethash "method" (%parse-lsp-json json)))
                      (%fake-sent-in-order transport))
              :to-equal (list "initialize" "initialized" "textDocument/didOpen"
                              "textDocument/didChange" method))
      (let* ((params (gethash "params" (%fake-sent-message transport 3)))
             (document (gethash "textDocument" params)))
        (expect (gethash "version" document) :to-equal 2)
        (expect (gethash "text" (first (gethash "contentChanges" params)))
                :to-equal "!foo"))
      (funcall command)
      (expect (mapcar (lambda (json) (gethash "method" (%parse-lsp-json json)))
                      (%fake-sent-in-order transport))
              :to-equal (list "initialize" "initialized" "textDocument/didOpen"
                              "textDocument/didChange" method method)))))

(describe
  "LSP navigation keybindings"
  (it-each
      (("C-M-i" (((:control :alt) . #\i))
        loom/feature/lsp:lsp-completion-at-point)
       ("M-." (((:alt) . #\.)) loom/feature/lsp:lsp-find-definition)
       ("M-," (((:alt) . #\,)) loom/feature/lsp:lsp-pop-definition))
      "binds ~A to its default command" (label key-sequence command)
    (declare (ignore label))
    (let ((keymap (make-keymap)))
      (loom/application:install-default-keybindings keymap)
      (expect (keymap-lookup keymap key-sequence) :to-be command))))
