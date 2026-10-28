(in-package #:loom/feature/lsp)

(defun lsp-session-capability (session name)
  "Return SESSION's advertised server capability NAME, or NIL.

A capability the server did not mention, or explicitly set to null or false,
all read as NIL: JSON false decodes to NIL already, so only null needs the
extra test."
  (let ((capabilities (lsp-session-server-capabilities session)))
    (when (hash-table-p capabilities)
      (let ((value (gethash name capabilities)))
        (unless (or (null value) (eq value json-kit:+json-null+))
          value)))))

(defun %lsp-request (session method params handler)
  "Send METHOD with PARAMS and register HANDLER for the matching response.

HANDLER is called with (RESULT ERROR-MESSAGE); both may be NIL on success. It runs
during LSP-SESSION-DRAIN, which the event loop calls between frames, so it may
touch editor state but must not block."
  (let ((id (%lsp-send-request session method params)))
    (setf (gethash id (lsp-session-pending-requests session)) handler)
    id))

(defun %lsp-pending-response-p (session message)
  (multiple-value-bind (id present-p) (%lsp-value-present-p message "id")
    (and present-p
         (nth-value 1 (gethash id (lsp-session-pending-requests session))))))

(defun %lsp-handle-pending-response (session message)
  "Deliver MESSAGE to the handler registered for its request id.

The handler is removed before it runs, so a handler that signals cannot leave
its own entry behind to be delivered a second time."
  (let* ((id (gethash "id" message))
         (handler (gethash id (lsp-session-pending-requests session))))
    (remhash id (lsp-session-pending-requests session))
    (when handler
      (multiple-value-bind (error-value error-present-p)
          (%lsp-value-present-p message "error")
        (if error-present-p
            (funcall handler nil (%lsp-json-error-message error-value))
            (funcall handler (gethash "result" message) nil))))))

(defun %lsp-text-document-position-params (uri line character &optional context)
  (json-kit:make-json-object
   (append
    (list (cons "textDocument"
                (json-kit:make-json-object (list (cons "uri" uri))))
          (cons "position"
                (json-kit:make-json-object
                 (list (cons "line" line) (cons "character" character)))))
    (when context (list (cons "context" context))))))

(defmacro define-lsp-position-request (name documentation capability method parser)
  "Define a position request whose reply is decoded before HANDLER runs.

The generated command is intentionally a thin declaration: transport and
pending-request bookkeeping stay in %LSP-REQUEST, while PARSER owns the wire
shape of the result."
  `(defun ,name (session uri line character handler)
     ,documentation
     (when (lsp-session-capability session ,capability)
       (%lsp-request session ,method
                     (%lsp-text-document-position-params uri line character)
                     (lambda (result error-message)
                       (funcall handler
                                (and (null error-message)
                                     (,parser result))
                                error-message))))))

(define-lsp-position-request lsp-request-completion
  "Ask SESSION for completions at LINE/CHARACTER in URI.

Returns NIL without sending anything when the server never advertised
completionProvider, which is what lets a caller say so instead of waiting for a
reply that is not coming."
  "completionProvider"
  "textDocument/completion"
  %lsp-parse-completion-result)

(define-lsp-position-request lsp-request-definition
  "Ask SESSION for the definition at LINE/CHARACTER in URI.

Returns NIL without sending anything when the server never advertised
definitionProvider."
  "definitionProvider"
  "textDocument/definition"
  %lsp-parse-definition-result)
(define-lsp-position-request lsp-request-hover
  "Ask SESSION for hover information at LINE/CHARACTER in URI.

Returns NIL without sending anything when the server never advertised
hoverProvider."
  "hoverProvider"
  "textDocument/hover"
  %lsp-parse-hover-result)
(defun lsp-request-references (session uri line character handler)
  "Ask SESSION for references at LINE/CHARACTER in URI.
The request includes declarations in the returned locations."
  (when (lsp-session-capability session "referencesProvider")
    (%lsp-request
     session "textDocument/references"
     (%lsp-text-document-position-params
      uri line character
      (json-kit:make-json-object
       (list (cons "includeDeclaration" t))))
     (lambda (result error-message)
       (funcall handler
                (and (null error-message)
                     (%lsp-parse-reference-result result))
                error-message)))))
(defun lsp-request-rename (session uri line character new-name handler)
  "Ask SESSION to rename the symbol at LINE/CHARACTER in URI to NEW-NAME."
  (when (lsp-session-capability session "renameProvider")
    (%lsp-request
     session "textDocument/rename"
     (json-kit:make-json-object
      (list (cons "textDocument"
                  (json-kit:make-json-object (list (cons "uri" uri))))
            (cons "position"
                  (json-kit:make-json-object
                   (list (cons "line" line) (cons "character" character))))
            (cons "newName" new-name)))
     (lambda (result error-message)
       (funcall handler result error-message)))))
(defun lsp-request-formatting (session uri options handler)
  "Ask SESSION to format the full document identified by URI."
  (when (lsp-session-capability session "documentFormattingProvider")
    (%lsp-request
     session "textDocument/formatting"
     (json-kit:make-json-object
      (list (cons "textDocument"
                  (json-kit:make-json-object (list (cons "uri" uri))))
            (cons "options" options)))
     handler)))

