;;;; packages/feature/lsp/src/application-lsp-protocol-routing.lisp
;;;;
;;;; Message classification and dispatch rules for one LSP session.
(in-package #:loom/feature/lsp)

(defun %lsp-shutdown-response-message-p (session message)
  (and (lsp-session-pending-shutdown-id session)
       (%lsp-message-id-matches-p
        message
        (lsp-session-pending-shutdown-id session))))

(defun %lsp-publish-diagnostics-message-p (message)
  (let ((method (gethash "method" message)))
    (and (stringp method)
         (string= method "textDocument/publishDiagnostics"))))

(defun %lsp-initialize-response-message-p (session message)
  (and (lsp-session-pending-initialize-id session)
       (%lsp-message-id-matches-p
        message
        (lsp-session-pending-initialize-id session))
       (multiple-value-bind (result result-present-p)
           (%lsp-value-present-p message "result")
         (declare (ignore result))
         (multiple-value-bind (error-value error-present-p)
             (%lsp-value-present-p message "error")
           (declare (ignore error-value))
           (or result-present-p error-present-p)))))

(defun %lsp-route-message (session message)
  (unless (hash-table-p message)
    (error "LSP message is not an object: ~S" message))
  (cond
    ((%lsp-shutdown-response-message-p session message)
     (%lsp-handle-shutdown-response session message))
    ((%lsp-publish-diagnostics-message-p message)
     (%lsp-handle-publish-diagnostics session message))
    ((%lsp-initialize-response-message-p session message)
     (%lsp-handle-initialize-response session message))))
