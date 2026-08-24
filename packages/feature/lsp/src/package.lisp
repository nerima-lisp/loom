;;;; packages/feature/lsp/src/package.lisp
;;;;
;;;; The public LSP package exposes values and session operations. JSON,
;;;; framing, and process lifecycle remain private infrastructure concerns.
(defpackage #:loom/feature/lsp
  (:use #:cl #:loom #:loom/application)
  (:export
   ;; Stable LSP values and session operations are the feature's public API.
   #:lsp-position
   #:make-lsp-position
   #:lsp-position-p
   #:lsp-position-line
   #:lsp-position-character
   #:lsp-range
   #:make-lsp-range
   #:lsp-range-p
   #:lsp-range-start
   #:lsp-range-end
   #:lsp-diagnostic
   #:make-lsp-diagnostic
   #:lsp-diagnostic-p
   #:lsp-diagnostic-range
   #:lsp-diagnostic-message
   #:lsp-diagnostic-severity
   #:lsp-diagnostic-source
   #:lsp-diagnostic-code
   #:lsp-diagnostic-severity-name
   #:lsp-document
   #:make-lsp-document
   #:lsp-document-p
   #:lsp-document-uri
   #:lsp-document-language-id
   #:lsp-document-version
   #:lsp-document-text
   #:make-lsp-session
   #:lsp-session-p
   #:lsp-session-start
   #:lsp-session-drain
   #:lsp-session-refresh
   #:lsp-session-sync-buffer
   #:lsp-session-diagnostics
   #:lsp-session-stop
   #:lsp-session-initialized-p
   #:lsp-session-server-capabilities
   #:lsp-session-server-info
   #:lsp-session-last-error
   #:lsp-path-uri
   #:lsp-discover-command
   ;; Application API
   #:lsp-start
   #:lsp-stop
   #:lsp-diagnostics
   #:lsp-completion-at-point
   #:lsp-find-definition
   #:lsp-pop-definition
   #:lsp-session-capability
   #:lsp-request-completion
   #:lsp-request-definition
   #:lsp-uri-path
   #:lsp-completion-item
   #:make-lsp-completion-item
   #:lsp-completion-item-p
   #:lsp-completion-item-label
   #:lsp-completion-item-insert-text
   #:lsp-completion-item-detail
   #:lsp-completion-item-kind
   #:lsp-completion-item-text
   #:lsp-location
   #:make-lsp-location
   #:lsp-location-p
   #:lsp-location-uri
   #:lsp-location-range))
