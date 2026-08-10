;;;; packages/feature/lsp/src/application-lsp-service.lisp
;;;;
;;;; Application-layer orchestration for one language-server session.  JSON
;;;; values and process I/O stay behind the infrastructure protocols; this
;;;; file owns request IDs, document versions, diagnostics, and the lifecycle
;;;; visible to commands and the main event loop.
(in-package #:loom/feature/lsp)

(defparameter *lsp-shutdown-timeout-seconds* 0.25
  "Maximum time LSP shutdown waits for a response before sending EXIT.")

(defstruct (lsp-session
            (:constructor %make-lsp-session))
  "The application state for one running Language Server Protocol session."
  transport
  command
  root-uri
  (next-id 0 :type integer)
  pending-initialize-id
  (initialized-p nil)
  server-capabilities
  server-info
  (documents (make-hash-table :test #'equal))
  (diagnostic-table (make-hash-table :test #'equal))
  pending-shutdown-id
  (exit-sent-p nil)
  last-error
  (closed-p nil))

(defun %lsp-uri-path-character-p (character)
  (or (char= character #\/)
      (or (and (char>= character #\0)
               (char<= character #\9))
          (and (char>= character #\A)
               (char<= character #\Z))
          (and (char>= character #\a)
               (char<= character #\z)))
      (find character "-._~:@!$&'()*+,;=" :test #'char=)))

(defun %lsp-uri-escape-path (path)
  (with-output-to-string (output)
    (loop for character across path
          do (if (%lsp-uri-path-character-p character)
                 (write-char character output)
                 (loop for octet across (%lsp-utf8-encode (string character))
                       do (format output "%~2,'0X" octet))))))

(defun lsp-path-uri (path)
  "Return the file URI used for PATH by Loom's minimal LSP client.

PATH is normally an absolute pathname supplied by a file-backed buffer.  The
path component is percent-encoded as UTF-8 while URI path separators and
unreserved characters remain readable."
  (format nil "file://~A"
          (%lsp-uri-escape-path (namestring (pathname path)))))

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

(defun lsp-session-start (session)
  "Send the LSP initialize request for SESSION once."
  (when (lsp-session-closed-p session)
    (error "Cannot start a closed LSP session"))
  (when (lsp-session-pending-shutdown-id session)
    (error "Cannot start a stopping LSP session"))
  (unless (or (lsp-session-initialized-p session)
              (lsp-session-pending-initialize-id session))
    (setf (lsp-session-pending-initialize-id session)
          (%lsp-send-request
           session
           "initialize"
           (%lsp-initialize-params session))))
  session)

(defun %lsp-buffer-uri (buffer-or-path)
  (cond
    ((loom:buffer-p buffer-or-path)
     (and (buffer-path buffer-or-path)
          (lsp-path-uri (buffer-path buffer-or-path))))
    ((or (pathnamep buffer-or-path) (stringp buffer-or-path))
     (lsp-path-uri buffer-or-path))
    (t nil)))

(defun lsp-session-sync-buffer (session buffer)
  "Send a full-text open or change notification for BUFFER."
  (unless (loom:buffer-p buffer)
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
               (json-kit:make-json-object
                (list
                 (cons "textDocument"
                       (json-kit:make-json-object
                        (list (cons "uri" uri)
                              (cons "version"
                                    (lsp-document-version document)))))
                 (cons "contentChanges"
                       (list
                        (json-kit:make-json-object
                         (list (cons "text" text)))))))))
            (let ((new-document
                    (make-lsp-document uri
                                       (%lsp-language-id (buffer-path buffer))
                                       1
                                       text)))
              (setf (gethash uri (lsp-session-documents session)) new-document)
              (%lsp-send-notification
               session
               "textDocument/didOpen"
               (json-kit:make-json-object
                (list
                 (cons "textDocument"
                       (json-kit:make-json-object
                        (list (cons "uri" uri)
                              (cons "languageId"
                                    (lsp-document-language-id new-document))
                              (cons "version"
                                    (lsp-document-version new-document))
                              (cons "text" text)))))))))))
  session))

(defun lsp-session-refresh (session buffer)
  "Drain responses and synchronize BUFFER during a render-loop turn."
  (unless (lsp-session-closed-p session)
    (handler-case
        (progn
          (lsp-session-drain session)
          (when (and (not (lsp-session-closed-p session))
                     (lsp-session-initialized-p session))
            (lsp-session-sync-buffer session buffer)))
      (error (condition)
        (setf (lsp-session-last-error session) (format nil "~A" condition)))))
  session)

(defun lsp-session-diagnostics (session buffer-or-path)
  "Return a copy of diagnostics associated with BUFFER-OR-PATH."
  (let ((uri (%lsp-buffer-uri buffer-or-path)))
    (copy-list (and uri (gethash uri (lsp-session-diagnostic-table session))))))

(defun %lsp-shutdown-deadline (timeout)
  (+ (get-internal-real-time)
     (ceiling (* (max 0 timeout) internal-time-units-per-second))))

(defun lsp-session-stop (session &key (timeout *lsp-shutdown-timeout-seconds*))
  "Gracefully stop SESSION, falling back to EXIT after TIMEOUT seconds.

The operation is idempotent.  An initialized server receives a shutdown
request and, when it acknowledges that request, the required exit
notification.  A non-responsive or malformed server still receives EXIT
before the transport is closed."
  (unless (lsp-session-closed-p session)
    (if (not (lsp-session-initialized-p session))
        (%lsp-finish-stop session)
        (progn
          (unless (lsp-session-pending-shutdown-id session)
            (handler-case
                (setf (lsp-session-pending-shutdown-id session)
                      (%lsp-send-request session "shutdown"))
              (error (condition)
                (setf (lsp-session-last-error session)
                      (format nil "~A" condition)))))
          (let ((deadline (%lsp-shutdown-deadline timeout)))
            (loop while (and (not (lsp-session-closed-p session))
                             (lsp-session-pending-shutdown-id session)
                             (< (get-internal-real-time) deadline))
                  do (lsp-session-drain session)
                     (when (and (not (lsp-session-closed-p session))
                                (lsp-session-pending-shutdown-id session))
                       (sleep 0.01))))
          (unless (lsp-session-closed-p session)
            (%lsp-finish-stop session)))))
  session)
