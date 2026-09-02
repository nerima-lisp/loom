;;;; packages/feature/lsp/src/application-lsp-session-state.lisp
;;;;
;;;; Application-layer state for one language-server session. JSON values and
;;;; process I/O stay behind the
;;;; infrastructure protocols; this file owns the persistent state visible to
;;;; commands and the main event loop.
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
  ;; Response handlers for requests the user drove, keyed by JSON-RPC id.
  ;; Initialize and shutdown keep their own dedicated slots because their
  ;; responses change the session's lifecycle rather than returning a value.
  (pending-requests (make-hash-table :test #'eql))
  pending-shutdown-id
  (exit-sent-p nil)
  last-error
  (closed-p nil))

(defun make-lsp-session (&key transport command directory root-uri)
  "Create an LSP session over TRANSPORT or a child process COMMAND.

Supplying TRANSPORT is the seam used by tests and future non-process
frontends. COMMAND is intentionally a shell command, so launching it has
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
