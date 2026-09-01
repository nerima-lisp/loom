(in-package #:loom/feature/format)

(defun %trim-format-command (command)
  (string-trim '(#\Space #\Tab #\Newline #\Return) command))

(defun %format-result-message (result)
  (if (shell-command-result-success-p result)
      "Buffer formatted successfully"
      (format nil "Formatter exited with code ~D"
              (shell-command-result-exit-code result))))

(defun %format-error-message (prefix condition)
  (format nil "~A error: ~A" prefix condition))

(defun format-current-buffer ()
  "Prompt for a formatter command and format the selected buffer."
  (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                :on-cancel (lambda () nil))
      ((command "Format command: "))
      (let ((command (%trim-format-command command)))
        (if (zerop (length command))
            (minibuffer-message
             (editor-state-minibuffer *editor-state*)
             "Format command cancelled")
            (handler-case
                (let ((result (format-buffer-with-command command)))
                  (minibuffer-message
                   (editor-state-minibuffer *editor-state*)
                   (%format-result-message result))
                  result)
              (error (condition)
                (minibuffer-message
                 (editor-state-minibuffer *editor-state*)
                 (%format-error-message "Format command" condition))))))))

(defun set-format-command (command &optional (state *editor-state*))
  "Set the shell COMMAND used by format-on-save in STATE.

The command is stored as a trimmed string and must not be empty."
  (check-type command string)
  (unless state
    (error "No editor state is active"))
    (let ((trimmed (%trim-format-command command)))
    (when (zerop (length trimmed))
      (error "The format command must not be empty"))
    (setf (editor-state-format-command state) trimmed)))

(defun format-on-save-mode (&optional (enabled-p nil enabled-p-supplied-p)
                              (state *editor-state*))
  "Toggle or set formatting before save in STATE.

When ENABLED-P is omitted, the mode toggles.  Enabling the mode requires a
formatter command to have been configured first."
  (unless state
    (error "No editor state is active"))
  (let ((enabled (if enabled-p-supplied-p
                    enabled-p
                    (not (editor-state-format-on-save-p state)))))
    (when (and enabled
               (zerop (length (or (editor-state-format-command state) ""))))
      (error "Set a format command before enabling format-on-save"))
    (setf (editor-state-format-on-save-p state) (not (null enabled)))))

(defun format-before-save (buffer &optional (state *editor-state*))
  "Format BUFFER in place before STATE writes it to disk.

Formatter failures are reported as data and do not prevent the ordinary save
from proceeding; this keeps an unavailable formatter from making a buffer
unsaveable."
  (when (and state
             (editor-state-format-on-save-p state)
             (editor-state-format-command state))
    (handler-case
        (let ((result (format-buffer-with-command
                       (editor-state-format-command state)
                       buffer)))
          (unless (shell-command-result-success-p result)
            (when (editor-state-minibuffer state)
               (minibuffer-message
               (editor-state-minibuffer state)
               (format nil "Format-on-save exited with code ~D"
                       (shell-command-result-exit-code result))))))
      (error (condition)
        (when (editor-state-minibuffer state)
          (minibuffer-message
           (editor-state-minibuffer state)
           (%format-error-message "Format-on-save" condition))))))
  buffer)

(defun set-format-command-command ()
  "Prompt for and set the formatter used by format-on-save."
  (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                :on-cancel (lambda () nil))
      ((command "Format-on-save command: "))
      (handler-case
          (progn
            (set-format-command command)
            (minibuffer-message
             (editor-state-minibuffer *editor-state*)
             "Format-on-save command set"))
        (error (condition)
          (minibuffer-message
           (editor-state-minibuffer *editor-state*)
           (format nil "Format-on-save command error: ~A" condition))))))
