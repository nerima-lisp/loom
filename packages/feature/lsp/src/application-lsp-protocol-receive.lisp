;;;; packages/feature/lsp/src/application-lsp-protocol-receive.lisp
;;;;
;;;; Incoming transport draining for one Language Server Protocol session.
;;;; Message routing, response handling, request construction, and diagnostic
;;;; payload decoding stay in neighboring protocol slices.
(in-package #:loom/feature/lsp)

(defun %lsp-handle-publish-diagnostics (session message)
  (multiple-value-bind (uri diagnostics)
      (%lsp-publish-diagnostics-payload message)
    (setf (gethash uri (lsp-session-diagnostic-table session))
          diagnostics)))

(defun %lsp-parse-received-message (json)
  (json-kit:parse
   json
   :object-type :hash-table
   :array-type :list
   :duplicate-key-policy :error
   :null-value json-kit:+json-null+
   :false-value nil))

(defun %lsp-drain-message (session)
  (let ((json (lsp-transport-receive (lsp-session-transport session))))
    (when json
      (%lsp-route-message session (%lsp-parse-received-message json)))
    json))

(defun lsp-session-drain (session)
  "Consume all currently available transport messages without blocking."
  (unless (lsp-session-closed-p session)
    (loop while (not (lsp-session-closed-p session))
          do (handler-case
                 (unless (%lsp-drain-message session)
                   (return))
               (error (condition)
                 (setf (lsp-session-last-error session)
                       (princ-to-string condition))
                 (return)))))
  session)
