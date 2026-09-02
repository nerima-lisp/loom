;;;; packages/feature/session/src/application-commands-session.lisp
;;;;
;;;; Application layer: save/load commands. Snapshot conversion lives in
;;;; application-session-snapshot.lisp; restore helpers live in
;;;; application-session-restore.lisp.
(in-package #:loom/feature/session)

(defun %session-path-present-p (path)
  "Return true when PATH contains a non-whitespace character."
  (and (stringp path)
       (plusp (length (string-trim '(#\Space #\Tab) path)))))

(defmacro %define-session-command
    (name documentation prompt success-format error-format &body body)
  "Define a session command with the standard path prompt and diagnostics."
  `(defun ,name ()
     ,documentation
     (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                    :on-cancel (minibuffer-message minibuffer "Quit"))
         ((path ,prompt))
       (if (%session-path-present-p path)
           (handler-case
               (progn
                 ,@body
                 (minibuffer-message
                  minibuffer
                  (format nil ,success-format path)))
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
 (session-store-write path (%session-snapshot-from-state)))

(%define-session-command
 load-session
 "Prompt for a session path and restore it after a successful read."
 "Load session: "
 "Session loaded: ~A"
 "Could not load session: ~A"
 (%restore-session-snapshot (session-store-read path)))
