;;;; packages/feature/lsp/src/application-lsp-protocol-responses.lisp
;;;;
;;;; Response handlers for initialize/shutdown requests in one LSP session.
(in-package #:loom/feature/lsp)

(defun %lsp-ensure-initialize-result-capabilities (result)
  (multiple-value-bind (capabilities capabilities-present-p)
      (%lsp-value-present-p result "capabilities")
    (if (or (not capabilities-present-p)
            (eq capabilities json-kit:+json-null+)
            (hash-table-p capabilities))
        capabilities
        (error "LSP initialize result has invalid capabilities"))))

(defun %lsp-ensure-initialize-result-server-info (result)
  (multiple-value-bind (server-info server-info-present-p)
      (%lsp-value-present-p result "serverInfo")
    (if (or (not server-info-present-p)
            (eq server-info json-kit:+json-null+)
            (hash-table-p server-info))
        server-info
        (error "LSP initialize result has invalid serverInfo"))))

(defun %lsp-complete-initialize (session capabilities server-info)
  (setf (lsp-session-initialized-p session) t
        (lsp-session-server-capabilities session)
        (if (hash-table-p capabilities)
            capabilities
            (json-kit:make-json-object nil))
        (lsp-session-server-info session)
        (and (hash-table-p server-info)
             server-info)
        (lsp-session-last-error session) nil)
  (%lsp-send-notification
   session
   "initialized"
   (json-kit:make-json-object nil)))

(defun %lsp-handle-initialize-response-success (session result)
  (unless (hash-table-p result)
    (error "LSP initialize response has no object result"))
  (%lsp-complete-initialize
   session
   (%lsp-ensure-initialize-result-capabilities result)
   (%lsp-ensure-initialize-result-server-info result)))

(defun %lsp-initialize-response-error (session message)
  (multiple-value-bind (error-value error-present-p)
      (%lsp-value-present-p message "error")
    (when (and error-present-p
               (not (or (null error-value)
                        (eq error-value json-kit:+json-null+))))
      (setf (lsp-session-last-error session)
            (%lsp-json-error-message error-value)))))

(defun %lsp-handle-initialize-response-payload (session message)
  (if (%lsp-initialize-response-error session message)
      nil
      (multiple-value-bind (result result-present-p)
          (%lsp-value-present-p message "result")
        (if result-present-p
            (%lsp-handle-initialize-response-success session result)
            (error "LSP initialize response has no object result")))))

(defun %lsp-handle-initialize-response (session message)
  (when (%lsp-message-id-matches-p
         message
         (lsp-session-pending-initialize-id session))
    (setf (lsp-session-pending-initialize-id session) nil)
    (handler-case
        (%lsp-handle-initialize-response-payload session message)
      (error (condition)
        (setf (lsp-session-last-error session)
              (format nil "~A" condition))))))

(defun %lsp-handle-shutdown-response (session message)
  (when (%lsp-message-id-matches-p
         message
         (lsp-session-pending-shutdown-id session))
    (setf (lsp-session-pending-shutdown-id session) nil)
    (multiple-value-bind (error-value error-present-p)
        (%lsp-value-present-p message "error")
      (when (and error-present-p
                 (not (or (null error-value)
                          (eq error-value json-kit:+json-null+))))
        (setf (lsp-session-last-error session)
              (%lsp-json-error-message error-value))))
    (%lsp-finish-stop session)))
