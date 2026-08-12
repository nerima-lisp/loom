;;;; packages/feature/lsp/src/application-lsp-protocol-initialize.lisp
;;;;
;;;; Initialize request parameters and advertised client capabilities for
;;;; one Language Server Protocol session.
(in-package #:loom/feature/lsp)

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
