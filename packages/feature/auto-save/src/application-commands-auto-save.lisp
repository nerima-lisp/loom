(in-package #:loom/feature/auto-save)

(defun auto-save-mode (&optional (enabled-p nil enabled-p-supplied-p))
  "Toggle or set global automatic saving for all registered buffers."
  (let ((state *editor-state*))
    (unless state
      (error "No editor state is active"))
    (let ((enabled (if enabled-p-supplied-p
                      (not (null enabled-p))
                      (not (editor-state-auto-save-mode-p state)))))
      (setf (editor-state-auto-save-mode-p state) enabled)
      (%auto-save-message "Auto-save mode ~:[disabled~;enabled~]" enabled)
      enabled)))

(defun toggle-auto-save ()
  "Toggle automatic saving for the selected buffer only."
  (let* ((state *editor-state*)
         (buffer (and state (%selected-buffer))))
    (unless (and state buffer)
      (error "No selected buffer is active"))
    (if (member buffer (editor-state-auto-save-buffers state) :test #'eq)
        (progn
          (setf (editor-state-auto-save-buffers state)
                (remove buffer
                        (editor-state-auto-save-buffers state)
                        :test #'eq))
          (%auto-save-message "Auto-save disabled for ~A" (buffer-name buffer))
          nil)
        (progn
          (push buffer (editor-state-auto-save-buffers state))
          (%auto-save-message "Auto-save enabled for ~A" (buffer-name buffer))
          t))))

(defun auto-save-current-buffer ()
  "Run an auto-save pass for the selected buffer and report its result."
  (handler-case
      (let ((path (auto-save-buffer)))
        (if path
            (%auto-save-message "Auto-saved ~A" (buffer-name (%selected-buffer)))
            (%auto-save-message "Auto-save skipped"))
        path)
    (error (condition)
      (%auto-save-message "Auto-save error: ~A" condition)
      nil)))
