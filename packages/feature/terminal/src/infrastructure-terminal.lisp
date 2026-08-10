(in-package #:loom/feature/terminal)

(declaim (special loom:*editor-state*))

(defun %terminal-selected-buffer (state)
  (let ((window-tree (and state (editor-state-window-tree state))))
    (when window-tree
      (window-buffer (window-tree-selected-window window-tree)))))

(defun %terminal-directory-for-buffer (buffer)
  (let ((path (and buffer (buffer-path buffer))))
    (if path
        (namestring
         (make-pathname :name nil
                        :type nil
                        :version nil
                        :defaults (pathname path)))
        (uiop:getcwd))))

(defun %terminal-buffer-name (state)
  (loop for index from 1
        for name = (if (= index 1)
                       "*Loom-Terminal*"
                       (format nil "*Loom-Terminal<~D>*" index))
        unless (find name (editor-state-buffers state)
                     :key #'buffer-name
                     :test #'string=)
          return name))

(defun start-terminal-session (&key
                                  (program (or (uiop:getenv "SHELL") "/bin/sh"))
                                  (args nil)
                                  directory
                                  (state *editor-state*))
  "Start PROGRAM in a PTY and return its terminal session."
  (unless state
    (error "An editor state is required to start a terminal session."))
  (let* ((selected-buffer (%terminal-selected-buffer state))
         (working-directory
           (or directory
               (%terminal-directory-for-buffer selected-buffer)))
         (name (%terminal-buffer-name state))
         (pty (cl-tty-kit:make-pty :program program
                                   :args args
                                   :directory working-directory)))
    (handler-case
        (let ((buffer (make-buffer :name name)))
          (buffer-set-read-only buffer t)
          (%make-terminal-session name
                                  program
                                  args
                                  working-directory
                                  buffer
                                  pty))
      (error (condition)
        (cl-tty-kit:close-pty pty)
        (error condition)))))

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

(defun terminal-session-for-buffer (buffer &optional (state *editor-state*))
  (find buffer
        (and state (editor-state-terminal-sessions state))
        :key #'terminal-session-buffer
        :test #'eq))

(defun poll-terminal-sessions (&optional (state *editor-state*))
  "Poll every live terminal owned by STATE."
  (dolist (session (and state (copy-list (editor-state-terminal-sessions state))))
    (terminal-session-poll session))
  state)

(defun resize-terminal-sessions (columns rows &optional (state *editor-state*))
  "Resize every live terminal session owned by STATE."
  (dolist (session (and state (editor-state-terminal-sessions state)))
    (terminal-session-resize session columns rows))
  state)
