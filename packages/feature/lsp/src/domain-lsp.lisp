;;;; packages/feature/lsp/src/domain-lsp.lisp
;;;;
;;;; Domain value objects for the Language Server Protocol.  The domain does
;;;; not know how JSON is encoded or how a language server is launched; it
;;;; only keeps the positions, ranges, diagnostics, and open document state
;;;; that the application layer needs to present and synchronize.
(in-package #:loom)

(defstruct (lsp-position
            (:constructor make-lsp-position (line character)))
  "A zero-based LSP document position."
  (line 0 :type integer)
  (character 0 :type integer))

(defstruct (lsp-range
            (:constructor make-lsp-range (start end)))
  "A half-open LSP range from START to END."
  start
  end)

(defstruct (lsp-diagnostic
            (:constructor make-lsp-diagnostic
                (range message &key severity source code)))
  "A diagnostic reported by a language server."
  range
  message
  severity
  source
  code)

(defun lsp-diagnostic-severity-name (severity)
  "Return the display label for the numeric LSP SEVERITY value."
  (case severity
    (1 "error")
    (2 "warning")
    (3 "info")
    (4 "hint")
    (otherwise "info")))

(defstruct (lsp-document
            (:constructor make-lsp-document
                (uri language-id version text)))
  "The document identity and version synchronized with a language server."
  uri
  language-id
  (version 1 :type integer)
  text)
