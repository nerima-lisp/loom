;;;; packages/feature/lsp/src/application-lsp-requests.lisp
;;;;
;;;; User-driven LSP requests: capability checks, request dispatch, and the
;;;; pending-response registry that pairs a reply with whoever asked for it.
;;;;
;;;; Diagnostics arrive unsolicited and are handled where they land. Completion
;;;; and definition are different: a command asks, and the answer comes back on
;;;; some later LSP-SESSION-DRAIN, so the asker has to leave behind something
;;;; for the reply to find.
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

HANDLER is called with (RESULT ERROR-MESSAGE): exactly one is non-NIL. It runs
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

(defun %lsp-text-document-position-params (uri line character)
  (json-kit:make-json-object
   (list (cons "textDocument"
               (json-kit:make-json-object (list (cons "uri" uri))))
         (cons "position"
               (json-kit:make-json-object
                (list (cons "line" line) (cons "character" character)))))))

(defun lsp-request-completion (session uri line character handler)
  "Ask SESSION for completions at LINE/CHARACTER in URI.

Returns NIL without sending anything when the server never advertised
completionProvider, which is what lets a caller say so instead of waiting for a
reply that is not coming."
  (when (lsp-session-capability session "completionProvider")
    (%lsp-request session "textDocument/completion"
                  (%lsp-text-document-position-params uri line character)
                  (lambda (result error-message)
                    (funcall handler
                             (and (null error-message)
                                  (%lsp-parse-completion-result result))
                             error-message)))))

(defun lsp-request-definition (session uri line character handler)
  "Ask SESSION for the definition at LINE/CHARACTER in URI.

Returns NIL without sending anything when the server never advertised
definitionProvider."
  (when (lsp-session-capability session "definitionProvider")
    (%lsp-request session "textDocument/definition"
                  (%lsp-text-document-position-params uri line character)
                  (lambda (result error-message)
                    (funcall handler
                             (and (null error-message)
                                  (%lsp-parse-definition-result result))
                             error-message)))))
