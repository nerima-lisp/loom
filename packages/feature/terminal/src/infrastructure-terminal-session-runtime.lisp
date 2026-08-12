(in-package #:loom/feature/terminal)

(defun %terminal-read-available (pty)
  (with-output-to-string (output)
    (handler-case
        (loop for chunk = (cl-tty-kit:pty-read pty)
              while (and chunk (plusp (length chunk)))
              do (write-string chunk output))
      ;; A PTY master commonly reports EIO for the final read after its
      ;; child exits. Data accumulated before that read is still useful.
      (error () nil))))

(defun %close-terminal-session (session)
  (let ((pty (terminal-session-pty session)))
    (when pty
      (let ((exit-code (ignore-errors (cl-tty-kit:pty-exit-code pty))))
        (when exit-code
          (setf (terminal-session-exit-code session) exit-code)))
      (ignore-errors (cl-tty-kit:close-pty pty))
      (setf (terminal-session-pty session) nil)))
  (setf (terminal-session-alive-p session) nil)
  session)

(defun %replace-terminal-buffer (buffer text)
  (unwind-protect
       (progn
         (buffer-set-read-only buffer nil)
         (unless (zerop (length (buffer-text buffer)))
           (let* ((end (buffer-offset-position
                        buffer
                        (length (buffer-text buffer))))
                  (end-line (buffer-position-line end))
                  (end-column (buffer-position-column end)))
             (buffer-delete-region buffer 0 0 end-line end-column)))
         (unless (zerop (length text))
           (buffer-insert-string buffer text))
         (buffer-mark-saved buffer)
         (let* ((end (buffer-offset-position buffer (length text)))
                (end-line (buffer-position-line end))
                (end-column (buffer-position-column end)))
           (buffer-set-point buffer end-line end-column))
         buffer)
    (buffer-set-read-only buffer t)))

(defun terminal-session-poll (session)
  "Read available PTY output into SESSION's buffer and update its status."
  (when (terminal-session-alive-p session)
    (let ((pty (terminal-session-pty session)))
      (if (null pty)
          (setf (terminal-session-alive-p session) nil)
          (let ((chunk (%terminal-read-available pty)))
            (unless (zerop (length chunk))
              (terminal-session-feed-output session chunk)
              (%replace-terminal-buffer
               (terminal-session-buffer session)
               (terminal-session-output session)))
            (unless (cl-tty-kit:pty-alive-p pty)
              (%close-terminal-session session))))))
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
      (ignore-errors
        (cl-tty-kit:pty-resize (terminal-session-pty session) columns rows))))
  session)

(defun stop-terminal-session (session)
  "Close SESSION's PTY and retain its transcript buffer."
  (%close-terminal-session session))
