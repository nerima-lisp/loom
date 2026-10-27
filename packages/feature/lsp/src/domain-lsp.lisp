(in-package #:loom/feature/lsp)

(defun lsp-column-to-character (text column)
  "Convert a character column in TEXT to the default LSP UTF-16 offset."
  (loop for index below (min column (length text))
        sum (if (> (char-code (char text index)) #xffff) 2 1)))

(defun lsp-character-to-column (text character)
  "Convert a UTF-16 offset to a character column, clamped to TEXT's end.
An offset inside a surrogate pair maps to the character's start."
  (loop with offset = 0
        for value across text
        for column from 0
        for width = (if (> (char-code value) #xffff) 2 1)
        when (> (+ offset width) character) do (return column)
        do (incf offset width)
        finally (return (length text))))

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
                (uri language-id version text &optional buffer)))
  "The document identity and version synchronized with a language server."
  uri
  language-id
  (version 1 :type integer)
  text
  (buffers (and buffer (list buffer))))
