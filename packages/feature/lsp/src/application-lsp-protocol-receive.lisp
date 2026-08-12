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

(defun lsp-session-drain (session)
  "Consume all currently available transport messages without blocking."
  (unless (lsp-session-closed-p session)
    (loop while (not (lsp-session-closed-p session))
          do (handler-case
                 (let ((json (lsp-transport-receive
                              (lsp-session-transport session))))
                   (unless json (return))
                   (%lsp-route-message
                    session
                    (json-kit:parse
                     json
                     :object-type :hash-table
                     :array-type :list
                     :duplicate-key-policy :error
                     :null-value json-kit:+json-null+
                     :false-value nil)))
               (error (condition)
                 (setf (lsp-session-last-error session)
                       (format nil "~A" condition))
                 (return)))))
  session)
