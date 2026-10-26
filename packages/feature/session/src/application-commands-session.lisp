(in-package #:loom/feature/session)

(defun %session-path-present-p (path)
  (and (stringp path)
       (not (string= (string-trim '(#\Space #\Tab) path) ""))))

(defmacro %define-session-command
    (name documentation prompt success-format error-format warning-format
     &body body)
  "Define a session command with the standard path prompt and diagnostics."
  `(defun ,name ()
     ,documentation
     (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                    :on-cancel (minibuffer-message minibuffer "Quit"))
         ((path ,prompt))
       (if (%session-path-present-p path)
           (handler-case
               (multiple-value-bind (result warning)
                   (progn ,@body)
                 (declare (ignore result))
                 (minibuffer-message
                  minibuffer
                  (if (and warning ,warning-format)
                      (format nil ,warning-format warning)
                      (format nil ,success-format path))))
             (error (condition)
               (minibuffer-message
                minibuffer
                (format nil ,error-format condition))))
           (minibuffer-message minibuffer "Session path cannot be empty")))))

(%define-session-command
 save-session
 "Prompt for a path and save the current editor session there."
 "Save session to: "
 "Session saved: ~A"
 "Could not save session: ~A"
 nil
 (session-store-write path (%session-snapshot-from-state)))

(%define-session-command
 load-session
 "Prompt for a session path and restore it after a successful read."
 "Load session: "
 "Session loaded: ~A"
 "Could not load session: ~A"
 "Session loaded with warning: ~A"
 (%restore-session-snapshot (session-store-read path)))
