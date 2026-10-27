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
(describe
  "LSP references at point"
  (it "reports the missing session without sending a request"
    (let ((*editor-state* (%lsp-navigation-state)))
      (loom/feature/lsp::lsp-find-references)
      (expect (minibuffer-message-string
               (editor-state-minibuffer *editor-state*))
              :to-equal "No LSP session for this buffer")))
  (it "does not request references when the server lacks the capability"
    (%with-lsp-navigation (transport session buffer :capabilities "{}")
      (let ((before (length (%fake-sent-in-order transport))))
        (loom/feature/lsp::lsp-find-references)
        (expect (minibuffer-message-string
                 (editor-state-minibuffer *editor-state*))
                :to-equal "Server does not provide references")
        (expect (length (%fake-sent-in-order transport))
                :to-equal before))))
  (it "sends UTF-16 position and declaration context, syncs dirty text, lists every result, and visits the selected row"
  (%with-lsp-navigation
      (transport session buffer
       :content (format nil "~C foo~%bar foo"
                        (code-char #x1f600)))
    (lsp-session-sync-buffer session buffer)
    (buffer-set-point buffer 1 7)
    (buffer-insert-string buffer "!")
    (buffer-set-point buffer 0 2)
    (loom/feature/lsp::lsp-find-references)
    (let* ((messages (%fake-sent-in-order transport))
           (methods
             (loop for json in messages
                   for method = (gethash "method" (%parse-lsp-json json))
                   when method collect method))
           (change-index (position "textDocument/didChange" methods
                                   :test #'equal))
           (references-index (position "textDocument/references" methods
                                       :test #'equal)))
      (expect (and change-index references-index
                   (< change-index references-index))
              :to-be-truthy)
      (expect (%lsp-last-request-method transport)
              :to-equal "textDocument/references"))
    (let* ((request (%parse-lsp-json
                     (car (last (%fake-sent-in-order transport)))))
           (params (gethash "params" request))
           (document (gethash "textDocument" params))
           (position (gethash "position" params))
           (context (gethash "context" params)))
      (expect (gethash "uri" document)
              :to-equal (lsp-path-uri (buffer-path buffer)))
      (expect (gethash "line" position) :to-equal 0)
      (expect (gethash "character" position) :to-equal 3)
      (expect (gethash "includeDeclaration" context) :to-be t))
    (%fake-push-and-drain
     transport session
     (format nil
             "{\"jsonrpc\":\"2.0\",\"id\":~D,\"result\":[{\"uri\":\"~A\",\"range\":{\"start\":{\"line\":0,\"character\":3},\"end\":{\"line\":0,\"character\":6}}},{\"uri\":\"~A\",\"range\":{\"start\":{\"line\":1,\"character\":4},\"end\":{\"line\":1,\"character\":7}}}]}"
             (%lsp-last-request-id transport)
             (lsp-path-uri (buffer-path buffer))
             (lsp-path-uri (buffer-path buffer))))
    (let* ((window
             (loom/core/window-tree:window-tree-selected-window
              (editor-state-window-tree *editor-state*)))
           (references (loom/core/window-tree:window-buffer window)))
      (expect (lsp-session-last-error session) :to-be nil)
      (expect (minibuffer-message-string
               (editor-state-minibuffer *editor-state*))
              :to-equal "References found: 2")
      (expect (buffer-name references) :to-equal "*Loom-References*")
      (expect (buffer-text references)
              :to-equal
              (format nil
                      "/tmp/main.lisp:1:3: ~C foo~%/tmp/main.lisp:2:5: bar foo!"
                      (code-char #x1f600)))
      (expect references :to-have-point (cons 0 0))
      (expect (loom/core/buffer:buffer-read-only-p references) :to-be t)
      (buffer-set-point references 1 0)
      (loom/feature/search:search-result-visit)
      (expect (loom/core/window-tree:window-buffer window) :to-be buffer)
      (expect buffer :to-have-point (cons 1 4)))))
  (it "reports an empty result"
    (%with-lsp-navigation (transport session buffer)
      (loom/feature/lsp::lsp-find-references)
      (%fake-push-and-drain
       transport session
       (format nil "{\"jsonrpc\":\"2.0\",\"id\":~D,\"result\":null}"
               (%lsp-last-request-id transport)))
      (expect (minibuffer-message-string
               (editor-state-minibuffer *editor-state*))
              :to-equal "No references found"))))
(describe
  "LSP references command availability"
  (it "registers a references command"
    (expect
     (fboundp
      (find-symbol "LSP-FIND-REFERENCES" "LOOM/FEATURE/LSP"))
     :to-be-truthy)))
(describe
  "LSP rename"
  (it "registers M-x command and reports a missing session before prompting"
    (let ((rename (find-symbol "LSP-RENAME" "LOOM/FEATURE/LSP")))
      (expect (and rename (fboundp rename)) :to-be-truthy)
      (when (and rename (fboundp rename))
        (let ((*editor-state* (%lsp-navigation-state)))
          (funcall rename)
          (expect (minibuffer-message-string
                   (editor-state-minibuffer *editor-state*))
                  :to-equal "No LSP session for this buffer")
          (expect (minibuffer-active-p
                   (editor-state-minibuffer *editor-state*))
                  :to-be nil)))))

  (it "requires renameProvider and sends the UTF-16 request with newName"
    (let ((rename (find-symbol "LSP-RENAME" "LOOM/FEATURE/LSP")))
      (expect (and rename (fboundp rename)) :to-be-truthy)
      (when (and rename (fboundp rename))
        (%with-lsp-navigation
            (transport session buffer :content (format nil "~C foo" (code-char #x1f600))
             :capabilities "{\"capabilities\":{\"renameProvider\":true}}")
          (progn (buffer-set-point buffer 0 4) (funcall rename))
          (expect (minibuffer-prompt-string
                   (editor-state-minibuffer *editor-state*))
                  :to-equal "Rename to: ")
          (%lsp-type-prompt-string (editor-state-minibuffer *editor-state*) "renamed")
          (minibuffer-handle-key
           (editor-state-minibuffer *editor-state*) (%lsp-confirm-prompt (editor-state-minibuffer *editor-state*)))
          (expect (%lsp-last-request-method transport)
                  :to-equal "textDocument/rename")
          (let* ((request (%parse-lsp-json
                           (car (last (%fake-sent-in-order transport)))))
                 (params (gethash "params" request))
                 (document (gethash "textDocument" params))
                 (position (gethash "position" params)))
            (expect (gethash "uri" document)
                    :to-equal (lsp-path-uri (buffer-path buffer)))
            (expect (gethash "line" position) :to-equal 0)
            (expect (gethash "character" position) :to-equal 5)
            (expect (gethash "newName" params) :to-equal "renamed"))
          (%fake-push-and-drain
           transport session
           (format nil "{\"jsonrpc\":\"2.0\",\"id\":~D,\"result\":null}"
                   (%lsp-last-request-id transport)))))))

  (it "does not prompt or send a request without renameProvider"
    (let ((rename (find-symbol "LSP-RENAME" "LOOM/FEATURE/LSP")))
      (expect (and rename (fboundp rename)) :to-be-truthy)
      (when (and rename (fboundp rename))
        (%with-lsp-navigation (transport session buffer :capabilities "{}")
          (let ((before (length (%fake-sent-in-order transport))))
            (funcall rename)
            (expect (minibuffer-message-string
                     (editor-state-minibuffer *editor-state*))
                    :to-equal "Server does not provide rename")
            (expect (minibuffer-active-p
                     (editor-state-minibuffer *editor-state*))
                    :to-be nil)
            (expect (length (%fake-sent-in-order transport))
                    :to-equal before))))))

  (it "applies multiple edits in descending document order, groups undo, and resyncs after undo"
    (let ((rename (find-symbol "LSP-RENAME" "LOOM/FEATURE/LSP")))
      (expect (and rename (fboundp rename)) :to-be-truthy)
      (when (and rename (fboundp rename))
        (%with-lsp-navigation
            (transport session buffer :content "one two three"
             :capabilities "{\"capabilities\":{\"hoverProvider\":true,\"renameProvider\":true}}")
          (funcall rename)
          (%lsp-type-prompt-string (editor-state-minibuffer *editor-state*) "renamed")
          (minibuffer-handle-key
           (editor-state-minibuffer *editor-state*) (%lsp-confirm-prompt (editor-state-minibuffer *editor-state*)))
          (%fake-push-and-drain
           transport session
           (format nil
                   "{\"jsonrpc\":\"2.0\",\"id\":~D,\"result\":{\"changes\":{\"~A\":[{\"range\":{\"start\":{\"line\":0,\"character\":8},\"end\":{\"line\":0,\"character\":13}},\"newText\":\"3\"},{\"range\":{\"start\":{\"line\":0,\"character\":0},\"end\":{\"line\":0,\"character\":3}},\"newText\":\"ONE!\"}]}}}"
                   (%lsp-last-request-id transport)
                   (lsp-path-uri (buffer-path buffer))))
          (expect (buffer-text buffer) :to-equal "ONE! two 3")
          (expect (lsp-document-text
                   (gethash (lsp-path-uri (buffer-path buffer))
                            (loom/feature/lsp::lsp-session-documents session)))
                  :to-equal "ONE! two 3")
          (loom/core/buffer:buffer-undo buffer)
          (progn
            (expect (buffer-text buffer) :to-equal "one two three")
            (expect (loom/core/buffer:buffer-point-offset buffer) :to-equal 0))
          (funcall (find-symbol "LSP-HOVER-AT-POINT" "LOOM/FEATURE/LSP"))
          (let* ((messages (%fake-sent-in-order transport))
                 (methods (mapcar (lambda (json)
                                    (gethash "method" (%parse-lsp-json json)))
                                  messages))
                 (change-index (position "textDocument/didChange" methods
                                         :from-end t :test #'equal))
                 (hover-index (position "textDocument/hover" methods
                                        :from-end t :test #'equal))
                 (change (and change-index
                              (%parse-lsp-json (nth change-index messages)))))
            (expect (and change-index hover-index (< change-index hover-index))
                    :to-be-truthy)
            (expect (gethash "text"
                             (first (gethash "contentChanges"
                                             (gethash "params" change))))
                    :to-equal "one two three"))
          (%fake-push-and-drain
           transport session
           (format nil "{\"jsonrpc\":\"2.0\",\"id\":~D,\"result\":null}"
                   (%lsp-last-request-id transport)))))))
  (it "recalls a matching rename input with M-p through M-x"
    (%with-lsp-navigation
        (transport session buffer
         :capabilities "{\"capabilities\":{\"renameProvider\":true}}")
      (let ((minibuffer
              (loom/core/minibuffer:make-minibuffer
               :history (history-kit:make-history))))
        (setf (editor-state-minibuffer *editor-state*) minibuffer)
        (loom::execute-extended-command)
        (%lsp-type-prompt-string minibuffer "lsp-rename")
        (%lsp-confirm-prompt minibuffer)
        (expect (minibuffer-prompt-string minibuffer) :to-equal "Rename to: ")
        (%lsp-type-prompt-string minibuffer "foo")
        (%lsp-confirm-prompt minibuffer)
        (expect (member "foo"
                        (loom/core/minibuffer:minibuffer-history-entries minibuffer)
                        :test (function equal))
                :to-be-truthy)
        (%fake-push-and-drain
         transport session
         (format nil "{\"jsonrpc\":\"2.0\",\"id\":~D,\"result\":null}"
                 (%lsp-last-request-id transport)))
        (loom::execute-extended-command)
        (%lsp-type-prompt-string minibuffer "lsp-rename")
        (%lsp-confirm-prompt minibuffer)
        (%lsp-type-prompt-string minibuffer "f")
        (minibuffer-handle-key
         minibuffer
         (cl-tty-kit:make-key-event :type :character :code (code-char 112)
                                    :modifiers (list :alt)))
        (expect (loom/core/minibuffer:minibuffer-input-string minibuffer)
                :to-equal "foo")
        (minibuffer-handle-key
         minibuffer
         (cl-tty-kit:make-key-event :type :character :code (code-char 110)
                                    :modifiers (list :alt)))
        (expect (loom/core/minibuffer:minibuffer-input-string minibuffer)
                :to-equal "f")
        (minibuffer-handle-key
         minibuffer
         (cl-tty-kit:make-key-event :type :character :code (code-char 112)
                                    :modifiers (list :alt)))
        (expect (loom/core/minibuffer:minibuffer-input-string minibuffer)
                :to-equal "foo")
        (minibuffer-handle-key
         minibuffer
         (cl-tty-kit:make-key-event :type :special :code :control-g))
        (expect (minibuffer-message-string minibuffer) :to-equal "Rename cancelled"))))

  (it "rejects typed invalid edits without opening a server URI"
    (%with-lsp-navigation (transport session buffer)
      (lsp-session-sync-buffer session buffer)
      (let ((apply-edit
              (find-symbol "%LSP-APPLY-WORKSPACE-EDIT" "LOOM/FEATURE/LSP")))
        (expect (and apply-edit (fboundp apply-edit)) :to-be-truthy)
        (when (and apply-edit (fboundp apply-edit))
          (labels ((refusal-reason (workspace-edit)
                     (let ((condition-value nil))
                       (handler-case
                           (funcall apply-edit
                                    session
                                    (loom/core/editor-session:editor-state-session
                                     *editor-state*)
                                    (%parse-lsp-json workspace-edit))
                         (error (condition)
                           (setf condition-value condition)))
                       (expect (typep condition-value
                                      'loom/feature/lsp::lsp-workspace-edit-error)
                               :to-be-truthy)
                       (and (typep condition-value
                                   'loom/feature/lsp::lsp-workspace-edit-error)
                            (loom/feature/lsp::lsp-workspace-edit-error-reason
                             condition-value)))))
            (expect (refusal-reason
                     "{\"changes\":{\"file:///tmp/not-open.lisp\":[]}}")
                    :to-equal :unsupported-uri)
            (expect (refusal-reason
                     "{\"documentChanges\":[{\"kind\":\"create\",\"uri\":\"file:///tmp/new.lisp\"}]}")
                    :to-equal :resource-operation)
            (expect (refusal-reason
                     (format nil
                             "{\"changes\":{\"~A\":[{\"range\":{\"start\":{\"line\":0,\"character\":0},\"end\":{\"line\":0,\"character\":3}},\"newText\":\"a\"},{\"range\":{\"start\":{\"line\":0,\"character\":2},\"end\":{\"line\":0,\"character\":3}},\"newText\":\"b\"}]}}"
                             (lsp-path-uri (buffer-path buffer))))
                    :to-equal :overlapping-edits)
            (expect (buffer-text buffer) :to-equal "foo"))))))

  (it "validates every document before applying any WorkspaceEdit text"
    (let ((apply-edit
            (find-symbol "%LSP-APPLY-WORKSPACE-EDIT" "LOOM/FEATURE/LSP")))
      (expect (and apply-edit (fboundp apply-edit)) :to-be-truthy)
      (when (and apply-edit (fboundp apply-edit))
        (%with-lsp-navigation (transport session buffer :content "main")
          (let* ((editor-session
                   (loom/core/editor-session:editor-state-session *editor-state*))
                 (other (make-buffer :name "other.lisp"
                                     :path "/tmp/other.lisp"
                                     :initial-content "other"))
                 (condition-value nil))
            (loom/feature/buffers:register-buffer editor-session other)
            (lsp-session-sync-buffer session buffer)
            (lsp-session-sync-buffer session other)
            (handler-case
                (funcall
                 apply-edit session editor-session
                 (%parse-lsp-json
                  (format nil
                          "{\"documentChanges\":[{\"textDocument\":{\"uri\":\"~A\",\"version\":1},\"edits\":[{\"range\":{\"start\":{\"line\":0,\"character\":0},\"end\":{\"line\":0,\"character\":1}},\"newText\":\"M\"}]},{\"textDocument\":{\"uri\":\"~A\",\"version\":1},\"edits\":[{\"range\":{\"start\":{\"line\":0,\"character\":0},\"end\":{\"line\":0,\"character\":99}},\"newText\":\"X\"}]}]}"
                          (lsp-path-uri (buffer-path buffer))
                          (lsp-path-uri (buffer-path other)))))
              (error (condition)
                (setf condition-value condition)))
            (expect (typep condition-value
                           'loom/feature/lsp::lsp-workspace-edit-error)
                    :to-be-truthy)
            (when (typep condition-value
                         'loom/feature/lsp::lsp-workspace-edit-error)
              (expect (loom/feature/lsp::lsp-workspace-edit-error-reason
                       condition-value)
                      :to-equal :invalid-position))
            (expect (buffer-text buffer) :to-equal "main")
            (expect (buffer-text other) :to-equal "other")))))))
(describe "LSP rename UTF-16 edits"
  (it "converts UTF-16 edit positions exactly and rejects a split surrogate pair"
    (let ((apply-edit
            (find-symbol "%LSP-APPLY-WORKSPACE-EDIT" "LOOM/FEATURE/LSP")))
      (expect (and apply-edit (fboundp apply-edit)) :to-be-truthy)
      (when (and apply-edit (fboundp apply-edit))
        (%with-lsp-navigation
            (transport session buffer
             :content (format nil "a~Cb" (code-char #x1f600)))
          (let* ((editor-session
                   (loom/core/editor-session:editor-state-session *editor-state*))
                 (uri (lsp-path-uri (buffer-path buffer)))
                 (before (buffer-text buffer)))
            (expect transport :to-be-truthy)
            (lsp-session-sync-buffer session buffer)
            (handler-case
                (funcall
                 apply-edit session editor-session
                 (%parse-lsp-json
                  (format nil
                          "{\"changes\":{\"~A\":[{\"range\":{\"start\":{\"line\":0,\"character\":2},\"end\":{\"line\":0,\"character\":3}},\"newText\":\"X\"}]}}"
                          uri)))
              (loom/feature/lsp::lsp-workspace-edit-error (condition)
                (expect
                 (loom/feature/lsp::lsp-workspace-edit-error-reason condition)
                 :to-equal :invalid-position)))
            (expect (buffer-text buffer) :to-equal before)
            (funcall
             apply-edit session editor-session
             (%parse-lsp-json
              (format nil
                      "{\"changes\":{\"~A\":[{\"range\":{\"start\":{\"line\":0,\"character\":1},\"end\":{\"line\":0,\"character\":3}},\"newText\":\"X\"}]}}"
                      uri)))
            (expect (buffer-text buffer) :to-equal "aXb")))))))
(describe "LSP rename safety refusals"
  (it "rejects version mismatch, read-only buffers, and edits outside narrowing"
    (let ((apply-edit
            (find-symbol "%LSP-APPLY-WORKSPACE-EDIT" "LOOM/FEATURE/LSP")))
      (expect (and apply-edit (fboundp apply-edit)) :to-be-truthy)
      (when (and apply-edit (fboundp apply-edit))
        (%with-lsp-navigation (transport session buffer :content "foo bar")
          (let* ((editor-session
                   (loom/core/editor-session:editor-state-session *editor-state*))
                 (uri (lsp-path-uri (buffer-path buffer))))
            (expect transport :to-be-truthy)
            (lsp-session-sync-buffer session buffer)
            (labels ((expect-refusal (workspace-edit expected-reason)
                       (let ((condition-value nil)
                             (before (buffer-text buffer)))
                         (handler-case
                             (funcall apply-edit session editor-session
                                      (%parse-lsp-json workspace-edit))
                           (error (condition)
                             (setf condition-value condition)))
                         (expect (typep condition-value
                                        'loom/feature/lsp::lsp-workspace-edit-error)
                                 :to-be-truthy)
                         (when (typep condition-value
                                      'loom/feature/lsp::lsp-workspace-edit-error)
                           (expect (loom/feature/lsp::lsp-workspace-edit-error-reason
                                    condition-value)
                                   :to-equal expected-reason))
                         (expect (buffer-text buffer) :to-equal before))))
              (expect-refusal
               (format nil
                       "{\"documentChanges\":[{\"textDocument\":{\"uri\":\"~A\",\"version\":0},\"edits\":[{\"range\":{\"start\":{\"line\":0,\"character\":0},\"end\":{\"line\":0,\"character\":3}},\"newText\":\"bar\"}]}]}"
                       uri)
               :version-mismatch)
              (loom/core/buffer:buffer-set-read-only buffer t)
              (expect-refusal
               (format nil
                       "{\"changes\":{\"~A\":[{\"range\":{\"start\":{\"line\":0,\"character\":0},\"end\":{\"line\":0,\"character\":3}},\"newText\":\"bar\"}]}}"
                       uri)
               :read-only)
              (loom/core/buffer:buffer-set-read-only buffer nil)
              (loom/core/buffer:buffer-narrow-to-region buffer 0 4 0 7)
              (expect-refusal
               (format nil
                       "{\"changes\":{\"~A\":[{\"range\":{\"start\":{\"line\":0,\"character\":0},\"end\":{\"line\":0,\"character\":3}},\"newText\":\"bar\"}]}}"
                       uri)
               :narrowing))))))))

