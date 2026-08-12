;;;; packages/feature/lsp/src/application-lsp-protocol-send.lisp
;;;;
;;;; Outgoing JSON-RPC message construction and transport writes for one
;;;; Language Server Protocol session.
(in-package #:loom/feature/lsp)

(defun %lsp-send-object (session object)
  (lsp-transport-send (lsp-session-transport session)
                      (json-kit:stringify object)))

(defun %lsp-send-notification (session method &optional (params nil params-p))
  (let ((fields (list (cons "jsonrpc" "2.0")
                      (cons "method" method))))
    (when params-p
      (setf fields (append fields (list (cons "params" params)))))
    (%lsp-send-object session (json-kit:make-json-object fields))))

(defun %lsp-send-request (session method &optional (params nil params-p))
  (let ((id (incf (lsp-session-next-id session))))
    (let ((fields (list (cons "jsonrpc" "2.0")
                        (cons "id" id)
                        (cons "method" method))))
      (when params-p
        (setf fields (append fields (list (cons "params" params)))))
      (%lsp-send-object session (json-kit:make-json-object fields)))
    id))
