(in-package #:loom/feature/lsp)

(defparameter *lsp-shutdown-timeout-seconds* 0.25
  "Maximum time LSP shutdown waits for a response before sending EXIT.")
(defvar *client-version-provider* nil)
(defun register-client-version-provider (owner function)
  "Register OWNER's provider for the client version sent to language servers.

FUNCTION is called without arguments and should return a version string.
Registering again as OWNER replaces its provider; a different owner is
rejected."
  (unless (functionp function)
    (error "LSP client version provider must be a function"))
  (when (and *client-version-provider*
             (not (equal (car *client-version-provider*) owner)))
    (error "LSP client version provider is already registered by ~S"
           (car *client-version-provider*)))
  (setf *client-version-provider* (cons owner function))
  function)
(defun %client-version ()
  (unless *client-version-provider*
    (error "LSP client version provider is not registered"))
  (funcall (cdr *client-version-provider*)))

(defstruct (lsp-session
            (:constructor %make-lsp-session))
  "The application state for one running Language Server Protocol session."
  transport
  command
  root-uri
  root-path
  language-id
  config-identity
  (next-id 0 :type integer)
  pending-initialize-id
  (initialized-p nil)
  server-capabilities
  server-info
  (documents (make-hash-table :test #'equal))
  (diagnostic-table (make-hash-table :test #'equal))
  (pending-requests (make-hash-table))
  pending-shutdown-id
  (exit-sent-p nil)
  transport-error
  last-error
  (closed-p nil))

(defun make-lsp-session (&key transport command directory root-uri root-path language-id config-identity)
  "Create an LSP session over TRANSPORT or a child process COMMAND."
  (let ((actual-transport
          (or transport
              (progn
                (unless command
                  (error "MAKE-LSP-SESSION needs TRANSPORT or COMMAND"))
                (make-lsp-process command :directory directory)))))
    (%make-lsp-session :transport actual-transport
                       :command command
                       :root-uri root-uri
                       :root-path root-path
                       :language-id language-id
                       :config-identity config-identity)))
