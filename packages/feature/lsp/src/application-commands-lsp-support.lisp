;;;; packages/feature/lsp/src/application-commands-lsp-support.lisp
;;;;
;;;; Internal helpers for LSP command prompting and session startup.
(in-package #:loom/feature/lsp)

(defun %lsp-buffer-directory (buffer)
  "Return BUFFER's containing directory, or NIL for an unsaved buffer."
  (let ((path (buffer-path buffer)))
    (and path
         (make-pathname :name nil
                        :type nil
                        :defaults (pathname path)))))

(defun %lsp-error-message (session)
  (or (lsp-session-last-error session) "unknown LSP error"))

(defun %lsp-command-prompt-string (discovered-command)
  (if discovered-command
      (format nil "LSP command [RET for ~A]: " discovered-command)
      "LSP command: "))

(defun %normalize-lsp-command (typed-command discovered-command)
  (or (and typed-command
           (let ((trimmed (string-trim '(#\Space #\Tab) typed-command)))
             (unless (zerop (length trimmed)) trimmed)))
      discovered-command))

(defun %install-lsp-session (new-session)
  (let ((old-session (editor-state-lsp-session *editor-state*)))
    (setf (editor-state-lsp-session *editor-state*) new-session)
    (when old-session
      (lsp-session-stop old-session))))

(defun %lsp-start-session (command directory)
  (let ((new-session nil)
        (root-uri (and directory (lsp-path-uri directory))))
    (handler-case
        (progn
          (setf new-session
                (make-lsp-session :command command
                                  :directory directory
                                  :root-uri root-uri))
          (lsp-session-start new-session)
          (%install-lsp-session new-session)
          (values new-session nil))
      (error (condition)
        (when new-session
          (lsp-session-stop new-session))
        (values nil condition)))))
