(in-package #:loom/feature/lsp)

(defun lsp-session-start (session)
  "Send initialize unless SESSION is already initialized or an initialization
request is pending."
  (when (lsp-session-closed-p session)
    (error "Cannot start a closed LSP session"))
  (when (lsp-session-pending-shutdown-id session)
    (error "Cannot start a stopping LSP session"))
  (unless (or (lsp-session-initialized-p session)
              (lsp-session-pending-initialize-id session))
    (handler-case
        (setf (lsp-session-pending-initialize-id session)
              (%lsp-send-request session "initialize"
                                 (%lsp-initialize-params session)))
      (lsp-transport-send-exit-error (condition)
        (setf (lsp-session-transport-error session) condition)
        (error condition))))
  session)

(defparameter *lsp-initialize-timeout-seconds* 1.0
  "Maximum time a request command waits for the server initialization reply.")

(defun %lsp-await-initialized (session)
  (let ((deadline (+ (get-internal-real-time)
                     (ceiling (* *lsp-initialize-timeout-seconds*
                                internal-time-units-per-second)))))
    (loop do (lsp-session-drain session)
          until (or (lsp-session-initialized-p session)
                    (lsp-session-closed-p session)
                    (>= (get-internal-real-time) deadline))
          do (sleep 0.01)))
  (lsp-session-initialized-p session))

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

The operation is idempotent. For an initialized session, the client attempts
a shutdown request and waits for acknowledgement or TIMEOUT. EXIT is
attempted before closing the transport; delivery is not guaranteed."
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

(defun lsp-refresh-editor-state (state)
  (let* ((editor-session
           (loom/core/editor-session:editor-state-session state))
         (buffer
           (loom/core/window-tree:window-buffer
            (loom/core/window-tree:window-tree-selected-window
             (editor-state-window-tree state))))
         (selected-session nil)
         (registry
           (and editor-session
                (member :feature/lsp
                        (loom/core/editor-session:editor-session-slice-names
                         editor-session))
                (lsp-session-registry-state-sessions
                 (%lsp-session-registry editor-session)))))
    (let ((*editor-state* state)
          (*editor-session* editor-session))
      (setf selected-session
            (and buffer (buffer-path buffer)
                 (%lsp-current-buffer-session buffer))
            (editor-state-lsp-session state) selected-session)
      (when selected-session
        (lsp-session-refresh selected-session buffer))
      (when registry
        (maphash
         (lambda (key session)
           (declare (ignore key))
           (unless (eq session selected-session)
             (handler-case
                 (lsp-session-drain session)
               (error (condition)
                 (setf (lsp-session-last-error session)
                       (princ-to-string condition))))))
         registry)))
    state))

(defun lsp-stop-editor-state-lsp-session (state)
  (let* ((editor-session
           (loom/core/editor-session:editor-state-session state))
         (legacy-session (editor-state-lsp-session state))
         (registry
           (and editor-session
                (member :feature/lsp
                        (loom/core/editor-session:editor-session-slice-names
                         editor-session))
                (lsp-session-registry-state-sessions
                 (%lsp-session-registry editor-session))))
         (sessions nil))
    (when registry
      (maphash (lambda (key session)
                 (declare (ignore key))
                 (push session sessions))
               registry))
    (when legacy-session
      (push legacy-session sessions))
    (dolist (session (remove-duplicates sessions :test #'eq))
      (lsp-session-stop session))
    (when registry
      (clrhash registry))
    (setf (editor-state-lsp-session state) nil)
    state))
