;;;; packages/feature/lsp/src/application-lsp-service.lisp
;;;;
;;;; Application-layer orchestration for one language-server session.  JSON
;;;; values and process I/O stay behind the infrastructure protocols; this
;;;; file owns request IDs, document versions, diagnostics, and the lifecycle
;;;; visible to commands and the main event loop.
(in-package #:loom)

(defstruct (lsp-session
            (:constructor %make-lsp-session))
  "The application state for one running Language Server Protocol session."
  transport
  command
  root-uri
  (next-id 0 :type integer)
  pending-initialize-id
  (initialized-p nil)
  (documents (make-hash-table :test #'equal))
  (diagnostic-table (make-hash-table :test #'equal))
  last-error
  (closed-p nil))

(defun %lsp-object (&rest entries)
  (make-loom-json-object entries))

(defun %lsp-array (&rest elements)
  (make-loom-json-array elements))

(defun %lsp-entry (key value)
  (cons key value))

(defun lsp-path-uri (path)
  "Return the file URI used for PATH by Loom's minimal LSP client.

PATH is normally an absolute pathname supplied by a file-backed buffer.  URI
escaping is deliberately deferred to a later protocol slice; JSON escaping is
still handled by the infrastructure JSON codec."
  (format nil "file://~A" (namestring (pathname path))))

(defun %lsp-language-id (path)
  (let ((type (string-downcase (or (pathname-type (pathname path)) ""))))
    (if (member type '("lisp" "cl" "asd") :test #'string=)
        "common-lisp"
        (if (plusp (length type)) type "plaintext"))))

(defun make-lsp-session (&key transport command directory root-uri)
  "Create an LSP session over TRANSPORT or a child process COMMAND.

Supplying TRANSPORT is the seam used by tests and future non-process
frontends.  COMMAND is intentionally a shell command, so launching it has
the same trust boundary as user initialization and Lisp evaluation."
  (let ((actual-transport
          (or transport
              (progn
                (unless command
                  (error "MAKE-LSP-SESSION needs TRANSPORT or COMMAND"))
                (make-lsp-process command :directory directory)))))
    (%make-lsp-session :transport actual-transport
                       :command command
                       :root-uri root-uri)))

(defun %lsp-send-object (session object)
  (lsp-transport-send (lsp-session-transport session)
                      (loom-json-encode object)))

(defun %lsp-send-notification (session method params)
  (%lsp-send-object
   session
   (%lsp-object
    (%lsp-entry "jsonrpc" "2.0")
    (%lsp-entry "method" method)
    (%lsp-entry "params" params))))

(defun %lsp-send-request (session method params)
  (let ((id (incf (lsp-session-next-id session))))
    (%lsp-send-object
     session
     (%lsp-object
      (%lsp-entry "jsonrpc" "2.0")
      (%lsp-entry "id" id)
      (%lsp-entry "method" method)
      (%lsp-entry "params" params)))
    id))

(defun lsp-session-start (session)
  "Send the LSP initialize request for SESSION once."
  (when (lsp-session-closed-p session)
    (error "Cannot start a closed LSP session"))
  (unless (or (lsp-session-initialized-p session)
              (lsp-session-pending-initialize-id session))
    (setf (lsp-session-pending-initialize-id session)
          (%lsp-send-request
           session
           "initialize"
           (%lsp-object
            (%lsp-entry "processId" +loom-json-null+)
            (%lsp-entry "rootUri"
                        (or (lsp-session-root-uri session)
                            +loom-json-null+))
             (%lsp-entry "capabilities" (%lsp-object))))))
  session)

(defun %lsp-json-error-message (value)
  (cond
    ((loom-json-object-p value)
     (let ((message (loom-json-object-get value "message" nil)))
       (if (stringp message)
           message
           (format nil "~S" value))))
    ((stringp value) value)
    (t (format nil "~S" value))))

(defun %lsp-value-present-p (object key)
  (multiple-value-bind (value present-p)
      (loom-json-object-get object key nil)
    (values value present-p)))

(defun %lsp-handle-initialize-response (session message)
  (multiple-value-bind (id id-present-p)
      (%lsp-value-present-p message "id")
    (when (and id-present-p
               (eql id (lsp-session-pending-initialize-id session)))
      (multiple-value-bind (error-value error-present-p)
          (%lsp-value-present-p message "error")
        (setf (lsp-session-pending-initialize-id session) nil)
        (if (and error-present-p
                 (not (or (null error-value)
                          (eq error-value +loom-json-null+))))
            (setf (lsp-session-last-error session)
                  (%lsp-json-error-message error-value))
            (progn
              (setf (lsp-session-initialized-p session) t
                    (lsp-session-last-error session) nil)
              (%lsp-send-notification
               session
               "initialized"
               (%lsp-object))))))))

(defun %lsp-parse-position (object)
  (unless (loom-json-object-p object)
    (error "LSP position is not an object: ~S" object))
  (let ((line (loom-json-object-get object "line" nil))
        (character (loom-json-object-get object "character" nil)))
    (unless (and (integerp line) (integerp character))
      (error "LSP position has invalid coordinates: ~S" object))
    (make-lsp-position line character)))

(defun %lsp-parse-range (object)
  (unless (loom-json-object-p object)
    (error "LSP diagnostic range is not an object: ~S" object))
  (make-lsp-range
   (%lsp-parse-position (loom-json-object-get object "start" nil))
   (%lsp-parse-position (loom-json-object-get object "end" nil))))

(defun %lsp-optional-diagnostic-value (object key)
  (multiple-value-bind (value present-p)
      (%lsp-value-present-p object key)
    (when (and present-p (not (eq value +loom-json-null+)))
      value)))

(defun %lsp-parse-diagnostic (object)
  (unless (loom-json-object-p object)
    (error "LSP diagnostic is not an object: ~S" object))
  (let ((message (loom-json-object-get object "message" nil)))
    (unless (stringp message)
      (error "LSP diagnostic has no message: ~S" object))
    (make-lsp-diagnostic
     (%lsp-parse-range (loom-json-object-get object "range" nil))
     message
     :severity (let ((value (%lsp-optional-diagnostic-value object "severity")))
                 (and (integerp value) value))
     :source (let ((value (%lsp-optional-diagnostic-value object "source")))
              (and (stringp value) value))
     :code (%lsp-optional-diagnostic-value object "code"))))

(defun %lsp-handle-publish-diagnostics (session message)
  (let* ((params (loom-json-object-get message "params" nil))
         (uri (and (loom-json-object-p params)
                   (loom-json-object-get params "uri" nil)))
         (items (and (loom-json-object-p params)
                     (loom-json-object-get params "diagnostics" nil))))
    (unless (and (stringp uri) (loom-json-array-p items))
      (error "Malformed publishDiagnostics notification: ~S" message))
    (setf (gethash uri (lsp-session-diagnostic-table session))
          (mapcar #'%lsp-parse-diagnostic (loom-json-array-elements items)))))

(defun %lsp-handle-message (session message)
  (unless (loom-json-object-p message)
    (error "LSP message is not an object: ~S" message))
  (let ((method (loom-json-object-get message "method" nil)))
    (cond
      ((and (stringp method)
            (string= method "textDocument/publishDiagnostics"))
       (%lsp-handle-publish-diagnostics session message))
      ((lsp-session-pending-initialize-id session)
       (%lsp-handle-initialize-response session message)))))

(defun lsp-session-drain (session)
  "Consume all currently available transport messages without blocking."
  (unless (lsp-session-closed-p session)
    (loop
      (handler-case
          (let ((json (lsp-transport-receive (lsp-session-transport session))))
            (unless json (return))
            (%lsp-handle-message session (loom-json-parse json)))
        (error (condition)
          (setf (lsp-session-last-error session) (format nil "~A" condition))
          (return)))))
  session)

(defun %lsp-buffer-uri (buffer-or-path)
  (cond
    ((buffer-p buffer-or-path)
     (and (buffer-path buffer-or-path)
          (lsp-path-uri (buffer-path buffer-or-path))))
    ((or (pathnamep buffer-or-path) (stringp buffer-or-path))
     (lsp-path-uri buffer-or-path))
    (t nil)))

(defun lsp-session-sync-buffer (session buffer)
  "Send a full-text open or change notification for BUFFER."
  (unless (buffer-p buffer)
    (error "LSP buffer synchronization needs a BUFFER: ~S" buffer))
  (let ((uri (%lsp-buffer-uri buffer)))
    (when (and uri (lsp-session-initialized-p session))
      (let* ((text (buffer-text buffer))
             (document (gethash uri (lsp-session-documents session))))
        (if document
            (unless (string= text (lsp-document-text document))
              (incf (lsp-document-version document))
              (setf (lsp-document-text document) text)
              (%lsp-send-notification
               session
               "textDocument/didChange"
               (%lsp-object
                (%lsp-entry
                 "textDocument"
                 (%lsp-object
                  (%lsp-entry "uri" uri)
                  (%lsp-entry "version"
                              (lsp-document-version document))))
                (%lsp-entry
                 "contentChanges"
                 (%lsp-array
                  (%lsp-object (%lsp-entry "text" text)))))))
            (let ((new-document
                    (make-lsp-document uri
                                       (%lsp-language-id (buffer-path buffer))
                                       1
                                       text)))
              (setf (gethash uri (lsp-session-documents session)) new-document)
              (%lsp-send-notification
               session
               "textDocument/didOpen"
               (%lsp-object
                (%lsp-entry
                 "textDocument"
                 (%lsp-object
                  (%lsp-entry "uri" uri)
                  (%lsp-entry "languageId"
                              (lsp-document-language-id new-document))
                  (%lsp-entry "version"
                              (lsp-document-version new-document))
                  (%lsp-entry "text" text)))))))))
  session))

(defun lsp-session-refresh (session buffer)
  "Drain responses and synchronize BUFFER during a render-loop turn."
  (unless (lsp-session-closed-p session)
    (handler-case
        (progn
          (lsp-session-drain session)
          (when (lsp-session-initialized-p session)
            (lsp-session-sync-buffer session buffer)))
      (error (condition)
        (setf (lsp-session-last-error session) (format nil "~A" condition)))))
  session)

(defun lsp-session-diagnostics (session buffer-or-path)
  "Return a copy of diagnostics associated with BUFFER-OR-PATH."
  (let ((uri (%lsp-buffer-uri buffer-or-path)))
    (copy-list (and uri (gethash uri (lsp-session-diagnostic-table session))))))

(defun lsp-session-stop (session)
  "Close SESSION and its transport.  The operation is idempotent."
  (unless (lsp-session-closed-p session)
    (setf (lsp-session-closed-p session) t)
    (ignore-errors (lsp-transport-close (lsp-session-transport session))))
  session)
