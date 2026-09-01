(in-package #:loom/feature/auto-save)

(defparameter *auto-save-interval* 5
  "Minimum number of seconds between automatic save passes.")

(defun %auto-save-message (control &rest arguments)
  (let ((minibuffer (and *editor-state*
                         (editor-state-minibuffer *editor-state*))))
    (when minibuffer
      (minibuffer-message minibuffer
                          (apply #'format nil control arguments)))))

(defun auto-save-enabled-p (&optional buffer)
  "Return true when automatic saving is enabled for BUFFER."
  (let* ((state *editor-state*)
         (buffer (or buffer (and state (%selected-buffer)))))
    (and state
         buffer
         (or (editor-state-auto-save-mode-p state)
             (member buffer
                     (editor-state-auto-save-buffers state)
                     :test #'eq)))))

(defun auto-save-buffer (&optional buffer)
  "Auto-save BUFFER when its mode and contents allow it."
  (let ((buffer (or buffer (%selected-buffer))))
    (when (and (auto-save-enabled-p buffer)
               (auto-save-eligible-p buffer))
      (auto-save-buffer-to-file buffer))))

(defun %auto-save-targets (state)
  (let* ((selected (%selected-buffer))
         (buffers (remove-duplicates
                   (append (copy-list (editor-state-buffers state))
                           (list selected))
                   :test #'eq)))
    (remove-if-not #'auto-save-enabled-p buffers)))

(defun %auto-save-due-p (last-run current-time force)
  "Return true when an automatic save pass should run now."
  (or force
      (null last-run)
      (>= (- current-time last-run) *auto-save-interval*)))

(defun %auto-save-attempt (buffer)
  "Save BUFFER, reporting its failure without aborting the save pass."
  (handler-case
      (auto-save-buffer buffer)
    (error (condition)
      (%auto-save-message
       "Auto-save error for ~A: ~A"
       (buffer-name buffer)
       condition)
      nil)))

(defun maybe-auto-save (&key force now)
  "Run an automatic save pass when the configured interval has elapsed.

This function is intentionally called from the event loop rather than
introducing a second thread into the editor's input path."
  (let ((state *editor-state*))
    (when state
      (let ((current-time (or now (get-universal-time)))
            (last-run (editor-state-auto-save-last-run-at state)))
        (when (%auto-save-due-p last-run current-time force)
          (setf (editor-state-auto-save-last-run-at state) current-time)
          (loop for buffer in (%auto-save-targets state)
                for path = (%auto-save-attempt buffer)
                when path collect path))))))
