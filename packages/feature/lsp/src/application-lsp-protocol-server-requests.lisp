(in-package #:loom/feature/lsp)

(defstruct (lsp-server-request
            (:constructor %make-lsp-server-request (id method params params-present-p)))
  id
  method
  params
  params-present-p
  (state :pending))

(define-condition lsp-server-invalid-params (error) ())

(defun %lsp-display-text (text)
  (map 'string
       (lambda (character)
         (let ((code (char-code character)))
           (if (or (and (< code 32) (/= code 9)) (<= 127 code 159))
               (code-char #xfffd)
               character)))
       text))

(defun %lsp-server-request-terminal-p (request)
  (member (lsp-server-request-state request)
          '(:responding :replied :send-failed :response-failed :discarded)))

(defun %lsp-send-server-response (session request field value)
  (unless (%lsp-server-request-terminal-p request)
    (handler-case
        (progn
          (%lsp-send-object
           session
           (json-kit:make-json-object
            (list (cons "jsonrpc" "2.0") (cons "id" (lsp-server-request-id request))
                  (cons field value)))
           ;; A failed write may have emitted bytes, so claim the response first.
           :before-send (lambda () (setf (lsp-server-request-state request) :responding)))
          (setf (lsp-server-request-state request) :replied)
          t)
      (error (condition)
        (if (eq (lsp-server-request-state request) :responding)
            (progn
              (setf (lsp-server-request-state request) :send-failed)
              (%lsp-record-error session condition)
              nil)
            (error condition))))))

(defun %lsp-send-server-error (session request code message)
  (handler-case
      (%lsp-send-server-response
       session request "error"
       (json-kit:make-json-object (list (cons "code" code) (cons "message" message))))
    (error (condition)
      (setf (lsp-server-request-state request) :response-failed)
      (%lsp-record-error session condition)
      nil)))

(defun %lsp-guard-server-request (session request function)
  (handler-case
      (funcall function)
    (lsp-server-invalid-params ()
      (%lsp-send-server-error session request -32602 "Invalid params"))
    (error (condition)
      (%lsp-record-error session condition)
      (unless (%lsp-server-request-terminal-p request)
        (%lsp-send-server-error session request -32603 "Internal error")))))

(defun %lsp-json-array-p (value)
  (and (vectorp value) (not (stringp value))))

(defun %lsp-validated-registration-array (params key)
  (unless (and (hash-table-p params) (%lsp-json-array-p (gethash key params)))
    (error 'lsp-server-invalid-params))
  (let ((registrations (gethash key params)))
    (loop for registration across registrations
          unless (and (hash-table-p registration)
                      (stringp (gethash "id" registration))
                      (stringp (gethash "method" registration)))
            do (error 'lsp-server-invalid-params))
    registrations))

(defun %lsp-validate-server-message-params (params)
  (unless (and (hash-table-p params) (stringp (gethash "message" params)))
    (error 'lsp-server-invalid-params))
  (multiple-value-bind (actions present-p) (gethash "actions" params)
    (when present-p
      (unless (%lsp-json-array-p actions)
        (error 'lsp-server-invalid-params))
      (loop for action across actions
            unless (and (hash-table-p action) (stringp (gethash "title" action)))
              do (error 'lsp-server-invalid-params)))))

(defun %lsp-validate-server-request (request)
  (let ((method (lsp-server-request-method request))
        (params (lsp-server-request-params request)))
    (unless (and (stringp method)
                 (or (not (lsp-server-request-params-present-p request))
                     (hash-table-p params)))
      (error 'lsp-server-invalid-params))
    (cond
      ((string= method "client/registerCapability")
       (%lsp-validated-registration-array params "registrations"))
      ((string= method "client/unregisterCapability")
       (%lsp-validated-registration-array params "unregisterations"))
      ((string= method "workspace/configuration")
       (unless (and (hash-table-p params) (%lsp-json-array-p (gethash "items" params)))
         (error 'lsp-server-invalid-params)))
      ((string= method "window/showMessageRequest")
       (%lsp-validate-server-message-params params)))))

(defun %lsp-clear-server-prompt (session)
  (setf (lsp-session-server-request-active session) nil
        (lsp-session-server-request-minibuffer session) nil
        (lsp-session-server-request-token session) nil))

(defun %lsp-complete-server-prompt (session request result)
  (when (eq request (lsp-session-server-request-active session))
    (%lsp-clear-server-prompt session))
  (%lsp-guard-server-request
   session request
   (lambda () (%lsp-send-server-response session request "result" result))))

(defun %lsp-show-server-prompt (session minibuffer request)
  (let* ((params (lsp-server-request-params request))
         (actions
           (map 'list (lambda (action)
                        (cons (%lsp-display-text (gethash "title" action)) action))
                (gethash "actions" params))))
    (minibuffer-activate
     minibuffer (format nil "~A: " (%lsp-display-text (gethash "message" params)))
     :completion-function (lambda (input)
                            (declare (ignore input))
                            (mapcar #'car actions))
     :on-confirm (lambda (input)
                   (%lsp-complete-server-prompt
                    session request (or (cdr (assoc input actions :test #'string=))
                                        json-kit:+json-null+)))
     :on-cancel (lambda ()
                  (%lsp-complete-server-prompt session request json-kit:+json-null+)))
    (setf (lsp-server-request-state request) :active
          (lsp-session-server-request-active session) request
          (lsp-session-server-request-minibuffer session) minibuffer
          (lsp-session-server-request-token session)
          (loom/core/minibuffer:minibuffer-activation-token minibuffer))))

(defun %lsp-show-next-server-request (session)
  (when (and (lsp-session-server-request-queue session)
             (not (lsp-session-closed-p session))
             *editor-state*)
    (let ((minibuffer (editor-state-minibuffer *editor-state*)))
      (when (and minibuffer
                 (not (loom/core/minibuffer:minibuffer-active-p minibuffer)))
        (let ((request (pop (lsp-session-server-request-queue session))))
          (%lsp-guard-server-request
           session request (lambda () (%lsp-show-server-prompt session minibuffer request))))))))

(defun %lsp-show-server-notice (params)
  (let ((text (%lsp-display-text (gethash "message" params)))
        (minibuffer (and *editor-state* (editor-state-minibuffer *editor-state*))))
    (if minibuffer
        (minibuffer-message minibuffer text)
        (loom/core/minibuffer:minibuffer-log-message text))))

(defun %lsp-dispatch-server-request (session request)
  (let ((method (lsp-server-request-method request))
        (params (lsp-server-request-params request)))
    (cond
      ((string= method "client/registerCapability")
       (loop for registration across (gethash "registrations" params)
             do (setf (gethash (gethash "id" registration) (lsp-session-registrations session))
                      registration))
       (%lsp-send-server-response session request "result" json-kit:+json-null+))
      ((string= method "client/unregisterCapability")
       (loop for registration across (gethash "unregisterations" params)
             do (remhash (gethash "id" registration) (lsp-session-registrations session)))
       (%lsp-send-server-response session request "result" json-kit:+json-null+))
      ((string= method "workspace/configuration")
       (%lsp-send-server-response
        session request "result" (make-array (length (gethash "items" params))
                                             :initial-element json-kit:+json-null+)))
      ((string= method "workspace/workspaceFolders")
       (%lsp-send-server-response
        session request "result" (or (%lsp-workspace-folders (lsp-session-root-uri session))
                                     json-kit:+json-null+)))
      ((string= method "window/workDoneProgress/create")
       (%lsp-send-server-response session request "result" json-kit:+json-null+))
      ((string= method "window/showMessageRequest")
       (if (plusp (length (gethash "actions" params)))
           (setf (lsp-server-request-state request) :queued
                 (lsp-session-server-request-queue session)
                 (append (lsp-session-server-request-queue session) (list request)))
           (progn
             (%lsp-show-server-notice params)
             (%lsp-send-server-response session request "result" json-kit:+json-null+))))
      (t
       (loom/core/minibuffer:minibuffer-log-message
        (format nil "lsp: unhandled server request ~A" (%lsp-display-text method)))
       (%lsp-send-server-error session request -32601 "Method not found")))))

(defun %lsp-handle-server-request (session message)
  (let ((request (%make-lsp-server-request
                  (gethash "id" message) (gethash "method" message)
                  (gethash "params" message) (nth-value 1 (gethash "params" message)))))
    (%lsp-guard-server-request
     session request
     (lambda ()
       (%lsp-validate-server-request request)
       (%lsp-dispatch-server-request session request)))))



