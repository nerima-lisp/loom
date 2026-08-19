(in-package #:loom/feature/terminal)

(defun %terminal-session-for-selected-buffer ()
  (terminal-session-for-buffer (%selected-buffer)))

(defun %terminal-event-kind-acceptable-p (event)
  (let ((kind (cl-tty-kit:key-event-kind event)))
    (or (null kind) (member kind '(:press :repeat) :test #'eq))))

(defun %terminal-control-special-p (code)
  (and (keywordp code)
       (let ((name (symbol-name code)))
         (or (string= name "CONTROL-SPACE")
             (and (> (length name) 8)
                  (string= "CONTROL-" name :end2 8))))))

(defun terminal-input-event-p (event)
  "Whether EVENT should be sent to the selected terminal session."
  (let ((session (%terminal-session-for-selected-buffer)))
    (and session
         (terminal-session-alive-p session)
         (%terminal-event-kind-acceptable-p event)
         (case (cl-tty-kit:key-event-type event)
           (:character t)
           (:paste t)
           (:special
            (or (member (cl-tty-kit:key-event-code event)
                        +terminal-special-codes+
                        :test #'eq)
                (%terminal-control-special-p
                 (cl-tty-kit:key-event-code event))))
           (otherwise nil)))))
