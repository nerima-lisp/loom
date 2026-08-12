;;;; packages/feature/lsp/src/application-lsp-session-sync.lisp
;;;;
;;;; Buffer-to-document synchronization and diagnostic lookup for one
;;;; language-server session.
(in-package #:loom/feature/lsp)

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

(defun lsp-session-diagnostics (session buffer-or-path)
  "Return a copy of diagnostics associated with BUFFER-OR-PATH."
  (let ((uri (%lsp-buffer-uri buffer-or-path)))
    (copy-list (and uri (gethash uri (lsp-session-diagnostic-table session))))))
