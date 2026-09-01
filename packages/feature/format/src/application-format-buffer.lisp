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

(defun %format-replace-buffer-text (buffer source formatted point-offset mark-offset)
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
      (%format-set-position-from-offset buffer mark-offset :mark t))))

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
      (%format-replace-buffer-text
       buffer source (shell-command-result-output result)
       point-offset mark-offset))
    result))
