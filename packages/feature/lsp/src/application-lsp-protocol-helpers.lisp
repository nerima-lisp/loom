;;;; packages/feature/lsp/src/application-lsp-protocol-helpers.lisp
;;;;
;;;; Shared JSON-RPC helpers, response matching, and stop finalization for
;;;; one Language Server Protocol session.
(in-package #:loom/feature/lsp)

(defun %lsp-json-error-message (value)
  (cond
    ((hash-table-p value)
     (let ((message (gethash "message" value)))
       (if (stringp message)
           message
           (format nil "~S" value))))
    ((stringp value) value)
    (t (format nil "~S" value))))

(defun %lsp-value-present-p (object key)
  (multiple-value-bind (value present-p)
      (gethash key object)
    (values value present-p)))

(defun %lsp-message-id-matches-p (message id)
  (multiple-value-bind (message-id present-p)
      (%lsp-value-present-p message "id")
    (and present-p (eql message-id id))))

(defun %lsp-finish-stop (session)
  (unless (lsp-session-exit-sent-p session)
    (ignore-errors (%lsp-send-notification session "exit"))
    (setf (lsp-session-exit-sent-p session) t))
  (setf (lsp-session-closed-p session) t)
  (ignore-errors (lsp-transport-close (lsp-session-transport session)))
  session)
