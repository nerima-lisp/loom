;;;; packages/feature/lsp/src/application-lsp-request-decode.lisp
;;;;
;;;; Decoding for the request/response pairs a user drives directly --
;;;; completion and definition -- as opposed to the diagnostics the server
;;;; pushes on its own. Position and range parsing is shared with
;;;; application-lsp-diagnostic-decode.lisp.
(in-package #:loom/feature/lsp)

(defun %lsp-completion-items (result)
  "Return the items in a textDocument/completion RESULT.

The response is allowed to be a bare array, a CompletionList object with an
`items' key, or null when the server has nothing to offer; all three mean the
same thing to a caller and are flattened to a list here."
  (cond
    ((or (null result) (eq result json-kit:+json-null+)) '())
    ((listp result) result)
    ((hash-table-p result)
     (let ((items (gethash "items" result)))
       (if (listp items) items '())))
    (t '())))

(defun %lsp-parse-completion-item (object)
  (unless (hash-table-p object)
    (error "LSP completion item is not an object: ~S" object))
  (let ((label (gethash "label" object)))
    (unless (stringp label)
      (error "LSP completion item has no label: ~S" object))
    (make-lsp-completion-item
     label
     :insert-text (let ((value (%lsp-optional-diagnostic-value
                                object "insertText")))
                    (and (stringp value) value))
     :detail (let ((value (%lsp-optional-diagnostic-value object "detail")))
               (and (stringp value) value))
     :kind (let ((value (%lsp-optional-diagnostic-value object "kind")))
             (and (integerp value) value)))))

(defun %lsp-parse-completion-result (result)
  "Return the LSP-COMPLETION-ITEM values in a completion RESULT.

Items that do not decode are dropped rather than aborting the whole response:
one malformed candidate should not cost the user the other fifty."
  (loop for object in (%lsp-completion-items result)
        for item = (ignore-errors (%lsp-parse-completion-item object))
        when item
          collect item))

(defun %lsp-parse-location (object)
  (unless (hash-table-p object)
    (error "LSP location is not an object: ~S" object))
  (let ((uri (or (gethash "uri" object) (gethash "targetUri" object)))
        (range (or (gethash "range" object)
                   (gethash "targetSelectionRange" object)
                   (gethash "targetRange" object))))
    (unless (stringp uri)
      (error "LSP location has no uri: ~S" object))
    (make-lsp-location uri (%lsp-parse-range range))))

(defun %lsp-parse-definition-result (result)
  "Return the LSP-LOCATION values in a textDocument/definition RESULT.

The response may be a single Location, an array of them, or an array of
LocationLinks whose fields are named differently; %LSP-PARSE-LOCATION accepts
either naming, and a null result means the server knows of no definition."
  (cond
    ((or (null result) (eq result json-kit:+json-null+)) '())
    ((hash-table-p result)
     (let ((location (ignore-errors (%lsp-parse-location result))))
       (if location (list location) '())))
    ((listp result)
     (loop for object in result
           for location = (ignore-errors (%lsp-parse-location object))
           when location
             collect location))
    (t '())))
