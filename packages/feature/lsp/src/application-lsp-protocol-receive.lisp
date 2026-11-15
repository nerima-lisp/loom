(in-package #:loom/feature/lsp)

(defun %lsp-handle-publish-diagnostics (session message)
  (multiple-value-bind (uri diagnostics)
      (%lsp-publish-diagnostics-payload message)
    (dolist (diagnostic diagnostics)
      (setf (lsp-diagnostic-message diagnostic)
            (%lsp-display-text (lsp-diagnostic-message diagnostic)))
      (when (lsp-diagnostic-source diagnostic)
        (setf (lsp-diagnostic-source diagnostic)
              (%lsp-display-text (lsp-diagnostic-source diagnostic))))
      (when (stringp (lsp-diagnostic-code diagnostic))
        (setf (lsp-diagnostic-code diagnostic)
              (%lsp-display-text (lsp-diagnostic-code diagnostic)))))
    (setf (gethash uri (lsp-session-diagnostic-table session))
          diagnostics)))

(defun %lsp-parse-received-message (json &optional (array-type :list) (false-value nil))
  (json-kit:parse
   json
   :object-type :hash-table
   :array-type array-type
   :duplicate-key-policy :error
   :null-value json-kit:+json-null+
   :false-value false-value))

(defun %lsp-drain-message (session)
  (let ((json (lsp-transport-receive (lsp-session-transport session))))
    (when json
      (let ((message (%lsp-parse-received-message json)))
        ;; Request validation must distinguish arrays, booleans, and null.
        (when (and (hash-table-p message)
                   (nth-value 1 (gethash "id" message))
                   (nth-value 1 (gethash "method" message)))
          (setf message (%lsp-parse-received-message json :vector json-kit:+json-false+)))
        (%lsp-route-message session message)))
    json))

(defun lsp-session-drain (session)
  "Drain currently available transport messages without opening prompts."
  (unless (lsp-session-closed-p session)
    (loop while (not (lsp-session-closed-p session))
          do (handler-case
                 (unless (%lsp-drain-message session)
                   (return))
               (error (condition)
                 (%lsp-record-error session condition)
                 (return)))))
  session)
