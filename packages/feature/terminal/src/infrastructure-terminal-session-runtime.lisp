(in-package #:loom/feature/terminal)

(defun %terminal-read-available (pty)
  (with-output-to-string (output)
    (handler-case
        (loop for chunk = (cl-tty-kit:pty-read pty)
              while (and chunk (string/= chunk ""))
              do (write-string chunk output))
      ;; A PTY master commonly reports EIO for the final read after its
      ;; child exits. Data accumulated before that read is still useful.
      (cl-tty-kit:pty-operation-failed () nil))))

(defun %close-terminal-session (session)
  (let ((pty (terminal-session-pty session)))
    (when pty
        (let ((exit-code
                (handler-case (cl-tty-kit:pty-exit-code pty)
                  (cl-tty-kit:pty-operation-failed () nil))))
        (when exit-code
          (setf (terminal-session-exit-code session) exit-code)))
      (handler-case (cl-tty-kit:close-pty pty)
        (cl-tty-kit:pty-operation-failed () nil))
      (setf (terminal-session-pty session) nil)))
  (setf (terminal-session-alive-p session) nil)
  session)

(defun %buffer-end-coordinates (buffer text)
  (let ((end (buffer-offset-position buffer (length text))))
    (values (buffer-position-line end)
            (buffer-position-column end))))

(defun %clear-terminal-buffer (buffer)
  (unless (string= (buffer-text buffer) "")
    (multiple-value-bind (end-line end-column)
        (%buffer-end-coordinates buffer (buffer-text buffer))
      (buffer-delete-region buffer 0 0 end-line end-column))))

(defun %replace-terminal-buffer (buffer text)
  (unwind-protect
       (progn
         (buffer-set-read-only buffer nil)
         (%clear-terminal-buffer buffer)
         (unless (string= text "")
           (buffer-insert-string buffer text))
         (buffer-mark-saved buffer)
         (multiple-value-bind (end-line end-column)
             (%buffer-end-coordinates buffer text)
           (buffer-set-point buffer end-line end-column))
         buffer)
    (buffer-set-read-only buffer t)))

(defun terminal-session-poll (session)
  "Read available PTY output into SESSION's buffer and update its status."
  (when (terminal-session-alive-p session)
    (let ((pty (terminal-session-pty session)))
      (if pty (let ((chunk (%terminal-read-available pty)))
            (unless (string= chunk "")
              (terminal-session-feed-output session chunk)
              (%replace-terminal-buffer
               (terminal-session-buffer session)
               (terminal-session-output session)))
            (unless (cl-tty-kit:pty-alive-p pty)
              (%close-terminal-session session))) (setf (terminal-session-alive-p session) nil))))
  session)

(defun terminal-session-send (session text)
  "Send TEXT to SESSION's PTY, returning SESSION when it is alive."
  (when (and (terminal-session-alive-p session)
             (terminal-session-pty session))
    (cl-tty-kit:pty-write (terminal-session-pty session) text)
    session))

(defun terminal-session-resize (session columns rows)
  "Resize SESSION's screen and PTY to COLUMNS by ROWS."
  (when (and (integerp columns)
             (plusp columns)
             (integerp rows)
             (plusp rows))
    (terminal-screen-resize (terminal-session-screen session) columns rows)
    (when (and (terminal-session-alive-p session)
               (terminal-session-pty session))
      (cl-tty-kit:pty-resize (terminal-session-pty session) columns rows)))
  session)

(defun stop-terminal-session (session)
  "Close SESSION's PTY and retain its transcript buffer."
  (%close-terminal-session session))
