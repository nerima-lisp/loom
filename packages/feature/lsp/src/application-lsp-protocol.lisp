;;;; packages/feature/lsp/src/application-lsp-protocol.lisp
;;;;
;;;; JSON message encoding and protocol handling for one Language Server
;;;; Protocol session.  Session lifecycle and document synchronization stay
;;;; in the neighboring application service.
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

(defun %lsp-client-capabilities ()
  (json-kit:make-json-object
   (list
    (cons "workspace"
          (json-kit:make-json-object
           (list (cons "workspaceFolders" t))))
    (cons "textDocument"
          (json-kit:make-json-object
           (list
            (cons "synchronization"
                  (json-kit:make-json-object
                   (list (cons "dynamicRegistration" t)))))))
    (cons "publishDiagnostics"
          (json-kit:make-json-object
           (list (cons "relatedInformation" t)))))))

(defun %lsp-initialize-params (session)
  (let ((root-uri (lsp-session-root-uri session)))
    (json-kit:make-json-object
     (append
      (list (cons "processId" json-kit:+json-null+)
            (cons "clientInfo"
                  (json-kit:make-json-object
                   (list (cons "name" "Loom")
                         (cons "version" "0.1.0"))))
            (cons "rootUri" (or root-uri json-kit:+json-null+))
            (cons "capabilities" (%lsp-client-capabilities)))
      (when root-uri
        (list
         (cons "workspaceFolders"
               (list
                (json-kit:make-json-object
                 (list (cons "uri" root-uri)
                       (cons "name" "Loom workspace")))))))))))

(defun %lsp-json-error-message (value)
  (cond
    ((hash-table-p value)
     (let ((message (gethash "message" value)))
       (if (stringp message)
           message
           (format nil "~S" value))))
    ((stringp value) value)
    (t (format nil "~S" value))))

(defun %lsp-value-present-p (object key)
  (multiple-value-bind (value present-p)
      (gethash key object)
    (values value present-p)))

(defun %lsp-message-id-matches-p (message id)
  (multiple-value-bind (message-id present-p)
      (%lsp-value-present-p message "id")
    (and present-p (eql message-id id))))

(defun %lsp-handle-initialize-response (session message)
  (when (%lsp-message-id-matches-p
         message
         (lsp-session-pending-initialize-id session))
    (multiple-value-bind (error-value error-present-p)
        (%lsp-value-present-p message "error")
      (setf (lsp-session-pending-initialize-id session) nil)
      (if (and error-present-p
               (not (or (null error-value)
                        (eq error-value json-kit:+json-null+))))
          (setf (lsp-session-last-error session)
                (%lsp-json-error-message error-value))
          (multiple-value-bind (result result-present-p)
              (%lsp-value-present-p message "result")
            (if (and result-present-p (hash-table-p result))
                (multiple-value-bind (capabilities capabilities-present-p)
                    (%lsp-value-present-p result "capabilities")
                  (if (or (not capabilities-present-p)
                          (eq capabilities json-kit:+json-null+)
                          (hash-table-p capabilities))
                      (multiple-value-bind (server-info server-info-present-p)
                          (%lsp-value-present-p result "serverInfo")
                        (if (or (not server-info-present-p)
                                (eq server-info json-kit:+json-null+)
                                (hash-table-p server-info))
                            (progn
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
                            (setf (lsp-session-last-error session)
                                  "LSP initialize result has invalid serverInfo")))
                      (setf (lsp-session-last-error session)
                            "LSP initialize result has invalid capabilities")))
                (setf (lsp-session-last-error session)
                      "LSP initialize response has no object result")))))))

(defun %lsp-finish-stop (session)
  (unless (lsp-session-exit-sent-p session)
    (ignore-errors (%lsp-send-notification session "exit"))
    (setf (lsp-session-exit-sent-p session) t))
  (setf (lsp-session-closed-p session) t)
  (ignore-errors (lsp-transport-close (lsp-session-transport session)))
  session)

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

(defun %lsp-parse-position (object)
  (unless (hash-table-p object)
    (error "LSP position is not an object: ~S" object))
  (let ((line (gethash "line" object))
        (character (gethash "character" object)))
    (unless (and (integerp line) (integerp character))
      (error "LSP position has invalid coordinates: ~S" object))
    (make-lsp-position line character)))

(defun %lsp-parse-range (object)
  (unless (hash-table-p object)
    (error "LSP diagnostic range is not an object: ~S" object))
  (make-lsp-range
   (%lsp-parse-position (gethash "start" object))
   (%lsp-parse-position (gethash "end" object))))

(defun %lsp-optional-diagnostic-value (object key)
  (multiple-value-bind (value present-p)
      (%lsp-value-present-p object key)
    (when (and present-p (not (eq value json-kit:+json-null+)))
      value)))

(defun %lsp-parse-diagnostic (object)
  (unless (hash-table-p object)
    (error "LSP diagnostic is not an object: ~S" object))
  (let ((message (gethash "message" object)))
    (unless (stringp message)
      (error "LSP diagnostic has no message: ~S" object))
    (make-lsp-diagnostic
     (%lsp-parse-range (gethash "range" object))
     message
     :severity (let ((value (%lsp-optional-diagnostic-value object "severity")))
                 (and (integerp value) value))
     :source (let ((value (%lsp-optional-diagnostic-value object "source")))
              (and (stringp value) value))
     :code (%lsp-optional-diagnostic-value object "code"))))

(defun %lsp-handle-publish-diagnostics (session message)
  (let* ((params (gethash "params" message))
         (uri (and (hash-table-p params)
                   (gethash "uri" params)))
         (items (and (hash-table-p params)
                     (gethash "diagnostics" params))))
    (unless (and (stringp uri) (listp items))
      (error "Malformed publishDiagnostics notification: ~S" message))
    (setf (gethash uri (lsp-session-diagnostic-table session))
          (mapcar #'%lsp-parse-diagnostic items))))

(defun %lsp-handle-message (session message)
  (unless (hash-table-p message)
    (error "LSP message is not an object: ~S" message))
  (let ((method (gethash "method" message)))
    (cond
      ((and (lsp-session-pending-shutdown-id session)
            (%lsp-message-id-matches-p
             message
             (lsp-session-pending-shutdown-id session)))
       (%lsp-handle-shutdown-response session message))
      ((and (stringp method)
            (string= method "textDocument/publishDiagnostics"))
       (%lsp-handle-publish-diagnostics session message))
      ((lsp-session-pending-initialize-id session)
       (%lsp-handle-initialize-response session message)))))

(defun lsp-session-drain (session)
  "Consume all currently available transport messages without blocking."
  (unless (lsp-session-closed-p session)
    (loop while (not (lsp-session-closed-p session))
          do (handler-case
          (let ((json (lsp-transport-receive (lsp-session-transport session))))
            (unless json (return))
            (%lsp-handle-message
             session
             (json-kit:parse
              json
              :object-type :hash-table
              :array-type :list
              :duplicate-key-policy :error
              :null-value json-kit:+json-null+
              :false-value nil)))
        (error (condition)
          (setf (lsp-session-last-error session) (format nil "~A" condition))
          (return)))))
  session)
