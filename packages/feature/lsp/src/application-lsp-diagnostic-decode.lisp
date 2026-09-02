;;;; packages/feature/lsp/src/application-lsp-diagnostic-decode.lisp
;;;;
;;;; Diagnostic payload decoding for one Language Server Protocol session.
(in-package #:loom/feature/lsp)

(defun %lsp-parse-position (object)
  (unless (hash-table-p object)
    (error "LSP position is not an object: ~S" object))
  (let ((line (gethash "line" object))
        (character (gethash "character" object)))
    (unless (and (integerp line) (integerp character))
      (error "LSP position has invalid coordinates: ~S" object))
    (make-lsp-position line character)))

(defun %lsp-position-p (object)
  (and (hash-table-p object)
       (integerp (gethash "line" object))
       (integerp (gethash "character" object))))

(defun %lsp-range-p (object)
  (and (hash-table-p object)
       (%lsp-position-p (gethash "start" object))
       (%lsp-position-p (gethash "end" object))))

(defun %lsp-parse-range (object)
  (unless (hash-table-p object)
    (error "LSP diagnostic range is not an object: ~S" object))
  (make-lsp-range
   (%lsp-parse-position (gethash "start" object))
   (%lsp-parse-position (gethash "end" object))))

(defun %lsp-optional-diagnostic-value (object key)
  (multiple-value-bind (value present-p)
      (%lsp-value-present-p object key)
    (when (and present-p (not (eq value json-kit:+json-null+)))
      value)))

(defun %lsp-diagnostic-severity (object)
  (let ((value (%lsp-optional-diagnostic-value object "severity")))
    (and (integerp value) value)))

(defun %lsp-diagnostic-source (object)
  (let ((value (%lsp-optional-diagnostic-value object "source")))
    (and (stringp value) value)))

(defun %lsp-parse-diagnostic (object)
  (unless (hash-table-p object)
    (error "LSP diagnostic is not an object: ~S" object))
  (let ((message (gethash "message" object)))
    (unless (stringp message)
      (error "LSP diagnostic has no message: ~S" object))
    (make-lsp-diagnostic
     (%lsp-parse-range (gethash "range" object))
     message
     :severity (%lsp-diagnostic-severity object)
     :source (%lsp-diagnostic-source object)
     :code (%lsp-optional-diagnostic-value object "code"))))

(defun %lsp-publish-diagnostics-payload (message)
  (let* ((params (gethash "params" message))
         (uri (and (hash-table-p params)
                   (gethash "uri" params)))
         (items (and (hash-table-p params)
                     (gethash "diagnostics" params))))
    (unless (and (stringp uri) (listp items))
      (error "Malformed publishDiagnostics notification: ~S" message))
    (values uri
            (mapcar #'%lsp-parse-diagnostic items))))
