(in-package #:loom/feature/terminal)

(defun terminal-handle-key-event (event)
  "Send EVENT to the selected terminal session."
  (let ((session (%terminal-session-for-selected-buffer)))
    (when (and session
               (terminal-input-event-p event))
      (let ((payload (%terminal-event-payload event)))
        (when payload
          (terminal-session-send session payload)
          t)))))

(defun terminal ()
  "Create and select a PTY-backed terminal buffer."
  (handler-case
      (let ((session (start-terminal-session)))
        (push session (editor-state-terminal-sessions *editor-state*))
        (%register-buffer (terminal-session-buffer session))
        (window-set-buffer (%selected-window) (terminal-session-buffer session))
        (multiple-value-bind (columns rows) (cl-tty-kit:terminal-size)
          (terminal-session-resize session columns rows))
        (terminal-session-poll session)
        (minibuffer-message
         (editor-state-minibuffer *editor-state*)
         (if (terminal-session-alive-p session)
             "Terminal started"
             "Terminal exited immediately"))
        session)
    (error (condition)
      (minibuffer-message
       (editor-state-minibuffer *editor-state*)
       (format nil "Terminal failed: ~A" condition))
      nil)))

(defun terminal-stop ()
  "Stop the terminal session shown by the selected buffer."
  (let ((session (%terminal-session-for-selected-buffer)))
    (if session
        (progn
          (stop-terminal-session session)
          (minibuffer-message
           (editor-state-minibuffer *editor-state*)
           "Terminal stopped")
          session)
        (minibuffer-message
         (editor-state-minibuffer *editor-state*)
         "The selected buffer is not a terminal"))))
