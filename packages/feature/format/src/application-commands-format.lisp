(in-package #:loom/feature/format)

(defun %format-buffer-directory (buffer)
  (let ((path (buffer-path buffer)))
    (if path
        (namestring
         (make-pathname :name nil :type nil :defaults (pathname path)))
        (uiop:getcwd))))

(defun %format-position-offset (buffer line column)
  (let ((offset column))
    (loop for current-line below line
          do (incf offset (1+ (length (buffer-line buffer current-line)))))
    offset))

(defun %format-set-position-from-offset (buffer offset &key mark)
  (let* ((bounded-offset
           (max 0 (min offset (length (buffer-text buffer)))))
         (position (buffer-offset-position buffer bounded-offset))
         (line (buffer-position-line position))
         (column (buffer-position-column position)))
    (if mark
        (buffer-set-mark buffer line column)
        (buffer-set-point buffer line column))))

(defun %format-mark-offset (buffer)
  (multiple-value-bind (line column) (buffer-mark buffer)
    (and line (%format-position-offset buffer line column))))

(defun format-buffer-with-command (command &optional (buffer (%selected-buffer)))
  "Format BUFFER by sending its complete text to COMMAND.

The command runs in BUFFER's file directory when one exists.  Its standard
output replaces the buffer only when the process exits successfully.  A
successful replacement is one undo group and restores point and mark by
their absolute text offsets.  Read-only and narrowed buffers are rejected
before the external command is started.  The shell-command-result is
returned in all non-signalling process cases."
  (check-type command string)
  (unless (loom:buffer-p buffer)
    (error 'type-error
           :datum buffer
           :expected-type '(satisfies loom:buffer-p)))
  (when (buffer-read-only-p buffer)
    (error 'buffer-read-only-error :buffer buffer))
  (when (buffer-narrowed-p buffer)
    (error "format-buffer-with-command does not format a narrowed buffer"))
  (let* ((source (buffer-text buffer))
         (point-offset (buffer-point-offset buffer))
         (mark-offset (%format-mark-offset buffer))
         (result (run-shell-command command
                                     :directory (%format-buffer-directory buffer)
                                     :input source)))
    (when (shell-command-result-success-p result)
      (let ((formatted (shell-command-result-output result)))
        (unless (string= source formatted)
          (buffer-record-undo-boundary buffer)
          (let ((end (buffer-offset-position buffer (length source))))
            (buffer-delete-region
             buffer
             0
             0
             (buffer-position-line end)
             (buffer-position-column end)))
          (buffer-insert-string buffer formatted)
          (%format-set-position-from-offset buffer point-offset)
          (when mark-offset
            (%format-set-position-from-offset buffer mark-offset :mark t)))))
    result))

(defun format-current-buffer ()
  "Prompt for a formatter command and format the selected buffer."
  (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                :on-cancel (lambda () nil))
      ((command "Format command: "))
      (let ((command
              (string-trim '(#\Space #\Tab #\Newline #\Return) command)))
        (if (zerop (length command))
            (minibuffer-message
             (editor-state-minibuffer *editor-state*)
             "Format command cancelled")
            (handler-case
                (let ((result (format-buffer-with-command command)))
                  (minibuffer-message
                   (editor-state-minibuffer *editor-state*)
                   (if (shell-command-result-success-p result)
                       "Buffer formatted successfully"
                       (format nil "Formatter exited with code ~D"
                               (shell-command-result-exit-code result))))
                  result)
              (error (condition)
                (minibuffer-message
                 (editor-state-minibuffer *editor-state*)
                 (format nil "Format command error: ~A" condition))))))))

(defun set-format-command (command &optional (state *editor-state*))
  "Set the shell COMMAND used by format-on-save in STATE.

The command is stored as a trimmed string and must not be empty."
  (check-type command string)
  (unless state
    (error "No editor state is active"))
  (let ((trimmed (string-trim '(#\Space #\Tab #\Newline #\Return)
                              command)))
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
           (format nil "Format-on-save error: ~A" condition))))))
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
