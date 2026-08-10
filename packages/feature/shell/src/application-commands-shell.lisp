(in-package #:loom/feature/shell)

(defparameter *shell-command-result-buffer-name* "*Loom-Pipe-Command*")

(defun %shell-command-result-buffer ()
  (or (find *shell-command-result-buffer-name*
            (%editor-buffers)
            :key #'buffer-name
            :test #'string=)
      (%register-buffer (make-buffer :name *shell-command-result-buffer-name*))))

(defun %shell-command-directory ()
  (let ((path (buffer-path (%selected-buffer))))
    (if path
        (namestring
         (make-pathname :name nil :type nil :defaults (pathname path)))
        (uiop:getcwd))))

(defun %move-shell-result-point-to-end (buffer)
  (let ((line (1- (buffer-line-count buffer))))
    (buffer-set-point buffer line (length (buffer-line buffer line)))))

(defun %show-shell-command-result (result)
  (let* ((buffer (%shell-command-result-buffer))
         (prefix (if (zerop (length (buffer-text buffer)))
                     ""
                     (format nil "~%"))))
    (%move-shell-result-point-to-end buffer)
    (buffer-insert-string
     buffer
     (format nil "~A~A" prefix (shell-command-result-text result)))
    (buffer-mark-saved buffer)
    (loom/feature/window:window-set-buffer (%selected-window) buffer)
    (minibuffer-message
     (editor-state-minibuffer *editor-state*)
     (if (shell-command-result-success-p result)
         "Pipe command finished successfully"
         (format nil "Pipe command exited with code ~D"
                 (shell-command-result-exit-code result))))
    result))

(defun pipe-command ()
  "Run a shell command in the selected file's directory.

The command's standard output, standard error, and exit code are displayed
in *Loom-Pipe-Command*."
  (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                :on-cancel (lambda () nil))
      ((command "Pipe command: "))
      (let ((command
              (string-trim '(#\Space #\Tab #\Newline #\Return) command)))
        (if (zerop (length command))
            (minibuffer-message
             (editor-state-minibuffer *editor-state*)
             "Pipe command cancelled")
            (handler-case
                (%show-shell-command-result
                 (run-shell-command command
                                     :directory (%shell-command-directory)))
              (error (condition)
                (minibuffer-message
                 (editor-state-minibuffer *editor-state*)
                 (format nil "Pipe command error: ~A" condition))))))))
