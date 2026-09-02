;;;; packages/feature/lsp/src/application-lsp-session-lifecycle.lisp
;;;;
;;;; Session lifecycle orchestration for one language-server session.
(in-package #:loom/feature/lsp)

(defun lsp-session-start (session)
  "Send the LSP initialize request for SESSION once."
  (when (lsp-session-closed-p session)
    (error "Cannot start a closed LSP session"))
  (when (lsp-session-pending-shutdown-id session)
    (error "Cannot start a stopping LSP session"))
  (unless (or (lsp-session-initialized-p session)
              (lsp-session-pending-initialize-id session))
    (setf (lsp-session-pending-initialize-id session)
          (%lsp-send-request
           session
           "initialize"
           (%lsp-initialize-params session))))
  session)

(defun lsp-session-refresh (session buffer)
  "Drain responses and synchronize BUFFER during a render-loop turn."
  (unless (lsp-session-closed-p session)
    (handler-case
        (progn
          (lsp-session-drain session)
          (when (and (not (lsp-session-closed-p session))
                     (lsp-session-initialized-p session))
            (lsp-session-sync-buffer session buffer)))
      (error (condition)
        (setf (lsp-session-last-error session) (princ-to-string condition)))))
  session)

(defun %lsp-shutdown-deadline (timeout)
  (+ (get-internal-real-time)
     (ceiling (* (max 0 timeout) internal-time-units-per-second))))

(defun %lsp-request-shutdown (session)
  (unless (lsp-session-pending-shutdown-id session)
    (handler-case
        (setf (lsp-session-pending-shutdown-id session)
              (%lsp-send-request session "shutdown"))
      (error (condition)
        (setf (lsp-session-last-error session)
              (princ-to-string condition))))))

(defun %lsp-await-shutdown (session timeout)
  (let ((deadline (%lsp-shutdown-deadline timeout)))
    (loop while (and (not (lsp-session-closed-p session))
                     (lsp-session-pending-shutdown-id session)
                     (< (get-internal-real-time) deadline))
          do (lsp-session-drain session)
             (when (and (not (lsp-session-closed-p session))
                        (lsp-session-pending-shutdown-id session))
               (sleep 0.01)))))

(defun lsp-session-stop (session &key (timeout *lsp-shutdown-timeout-seconds*))
  "Gracefully stop SESSION, falling back to EXIT after TIMEOUT seconds.

The operation is idempotent. An initialized server receives a shutdown
request and, when it acknowledges that request, the required exit
notification. A non-responsive or malformed server still receives EXIT
before the transport is closed."
  (check-type timeout (real 0))
  (unless (lsp-session-closed-p session)
    (if (lsp-session-initialized-p session)
        (progn
          (%lsp-request-shutdown session)
          (%lsp-await-shutdown session timeout)
          (unless (lsp-session-closed-p session)
            (%lsp-finish-stop session)))
        (%lsp-finish-stop session)))
  session)
