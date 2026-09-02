;;;; packages/feature/lsp/src/domain-lsp.lisp
;;;;
;;;; Domain value objects for the Language Server Protocol.  The domain does
;;;; not know how JSON is encoded or how a language server is launched; it
;;;; only keeps the positions, ranges, diagnostics, and open document state
;;;; that the application layer needs to present and synchronize.
(in-package #:loom/feature/lsp)

(defstruct (lsp-position
            (:constructor make-lsp-position
                (&optional (line 0) (character 0))))
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

(defstruct (lsp-completion-item
            (:constructor make-lsp-completion-item
                (label &key insert-text detail kind)))
  "One candidate from a textDocument/completion response.

LABEL is what the user reads; INSERT-TEXT is what goes into the buffer, and is
allowed to differ -- a server may label a function `foo(...)' while inserting
only `foo'. LSP-COMPLETION-ITEM-TEXT resolves which to use."
  label
  insert-text
  detail
  kind)

(defun lsp-completion-item-text (item)
  "Return the text ITEM inserts: its insertText when it has one, else its label."
  (or (lsp-completion-item-insert-text item)
      (lsp-completion-item-label item)))

(defstruct (lsp-location
            (:constructor make-lsp-location (uri range)))
  "A document location returned by textDocument/definition."
  uri
  range)

(defstruct (lsp-document
            (:constructor make-lsp-document
                (uri language-id version text)))
  "The document identity and version synchronized with a language server."
  uri
  language-id
  (version 1 :type integer)
  text)
