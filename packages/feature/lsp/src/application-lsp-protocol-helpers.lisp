(in-package #:loom/feature/lsp)

(defun %lsp-record-error (session condition)
  (setf (lsp-session-last-error session)
        (%lsp-display-text (princ-to-string condition))))

(defun %lsp-json-error-message (value)
  (%lsp-display-text
   (cond
     ((hash-table-p value)
      (let ((message (gethash "message" value)))
        (if (stringp message)
            message
            (prin1-to-string value))))
     ((stringp value) value)
     (t (prin1-to-string value)))))

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
  (dolist (request (lsp-session-server-request-queue session))
    (setf (lsp-server-request-state request) :discarded))
  (setf (lsp-session-server-request-queue session) nil)
  (when (lsp-session-server-request-active session)
    (setf (lsp-server-request-state (lsp-session-server-request-active session)) :discarded))
  (let ((minibuffer (lsp-session-server-request-minibuffer session)))
    (when (and minibuffer
               (loom/core/minibuffer:minibuffer-active-p minibuffer)
               (eq (loom/core/minibuffer:minibuffer-activation-token minibuffer)
                   (lsp-session-server-request-token session)))
      (loom/core/minibuffer:minibuffer-deactivate minibuffer)))
  (%lsp-clear-server-prompt session)
  (ignore-errors (lsp-transport-close (lsp-session-transport session)))
  session)
