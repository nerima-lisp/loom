(in-package #:loom/feature/lsp)

(defun %lsp-display-text (text)
  (map 'string
       (lambda (character)
         (let ((code (char-code character)))
           (if (or (and (< code 32) (/= code 9)) (<= 127 code 159))
               (code-char #xfffd)
               character)))
       text))

(defun %lsp-send-server-result (session id result)
  (%lsp-send-object
   session
   (json-kit:make-json-object
    (list (cons "jsonrpc" "2.0") (cons "id" id) (cons "result" result)))))

(defun %lsp-unhandled-server-request (session id method)
  (loom/core/minibuffer:minibuffer-log-message
   (format nil "lsp: unhandled server request ~A" (%lsp-display-text method)))
  (%lsp-send-object
   session
   (json-kit:make-json-object
    (list (cons "jsonrpc" "2.0") (cons "id" id)
          (cons "error"
                (json-kit:make-json-object
                 (list (cons "code" -32601) (cons "message" "Method not found"))))))))

(defun %lsp-complete-server-prompt (session id result)
  (setf (lsp-session-server-request-minibuffer session) nil)
  (%lsp-send-server-result session id result))

(defun %lsp-show-server-prompt (session minibuffer request)
  (let* ((id (gethash "id" request))
         (params (gethash "params" request))
         (actions
           (mapcar (lambda (action)
                     (cons (%lsp-display-text (gethash "title" action)) action))
                   (gethash "actions" params))))
    (setf (lsp-session-server-request-minibuffer session) minibuffer)
    (minibuffer-activate
     minibuffer (format nil "~A: " (%lsp-display-text (gethash "message" params)))
     :completion-function (lambda (input)
                            (declare (ignore input))
                            (mapcar #'car actions))
     :on-confirm (lambda (input)
                   (%lsp-complete-server-prompt
                    session id (or (cdr (assoc input actions :test #'string=))
                                   json-kit:+json-null+)))
     :on-cancel (lambda ()
                  (%lsp-complete-server-prompt session id json-kit:+json-null+)))))

(defun %lsp-show-next-server-request (session)
  ;; Run after input callbacks have finished so their continuation prompts win.
  (when (and (lsp-session-server-request-queue session)
             (not (lsp-session-closed-p session))
             *editor-state*)
    (let ((minibuffer (editor-state-minibuffer *editor-state*)))
      (when (and minibuffer
                 (not (loom/core/minibuffer:minibuffer-active-p minibuffer)))
        (%lsp-show-server-prompt
         session minibuffer (pop (lsp-session-server-request-queue session)))))))

(defun %lsp-handle-server-request (session request)
  (let ((id (gethash "id" request))
        (method (gethash "method" request))
        (params (gethash "params" request)))
    (cond
      ((string= method "client/registerCapability")
       (dolist (registration (gethash "registrations" params))
         (setf (gethash (gethash "id" registration) (lsp-session-registrations session))
               registration))
       (%lsp-send-server-result session id json-kit:+json-null+))
      ((string= method "client/unregisterCapability")
       (dolist (registration (gethash "unregisterations" params))
         (remhash (gethash "id" registration) (lsp-session-registrations session)))
       (%lsp-send-server-result session id json-kit:+json-null+))
      ((string= method "workspace/configuration")
       (%lsp-send-server-result
        session id (make-array (length (gethash "items" params))
                               :initial-element json-kit:+json-null+)))
      ((string= method "workspace/workspaceFolders")
       (%lsp-send-server-result
        session id (or (%lsp-workspace-folders (lsp-session-root-uri session))
                       json-kit:+json-null+)))
      ((string= method "window/workDoneProgress/create")
       (%lsp-send-server-result session id json-kit:+json-null+))
      ((string= method "window/showMessageRequest")
       (if (gethash "actions" params)
           (setf (lsp-session-server-request-queue session)
                 (append (lsp-session-server-request-queue session) (list request)))
           (%lsp-send-server-result session id json-kit:+json-null+)))
      (t (%lsp-unhandled-server-request session id method)))))
