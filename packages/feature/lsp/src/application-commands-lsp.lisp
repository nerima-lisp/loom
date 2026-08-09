;;;; packages/feature/lsp/src/application-commands-lsp.lisp
;;;;
;;;; Application-layer commands for starting an LSP child process and showing
;;;; diagnostics.  The session protocol owns transport, document versions,
;;;; and diagnostic values; this file only turns those values into editor
;;;; use-cases and a normal Loom buffer.
(in-package #:loom/feature/lsp)

(defparameter *lsp-diagnostics-buffer-name* "*Loom-Diagnostics*")

(defun %lsp-buffer-directory (buffer)
  "Return BUFFER's containing directory, or NIL for an unsaved buffer."
  (let ((path (buffer-path buffer)))
    (and path
         (make-pathname :name nil
                        :type nil
                        :defaults (pathname path)))))

(defun %lsp-diagnostics-buffer ()
  "Return the registered buffer used to display LSP diagnostics."
  (or (find *lsp-diagnostics-buffer-name*
            (loom/application:%editor-buffers)
            :key #'buffer-name
            :test #'string=)
      (loom/application:%register-buffer
       (make-buffer :name *lsp-diagnostics-buffer-name*))))

(defun %replace-buffer-text (buffer text)
  "Replace BUFFER's complete contents with TEXT and mark it saved."
  (let ((end (buffer-offset-position buffer (length (buffer-text buffer)))))
    (unless (and (zerop (buffer-position-line end))
                 (zerop (buffer-position-column end)))
      (buffer-delete-region buffer
                            0
                            0
                            (buffer-position-line end)
                            (buffer-position-column end)))
    (buffer-insert-string buffer text)
    (buffer-mark-saved buffer)))

(defun %lsp-diagnostics-text (buffer diagnostics)
  "Render DIAGNOSTICS for BUFFER as plain text suitable for a Loom buffer."
  (with-output-to-string (output)
    (format output "Diagnostics for ~A~%" (buffer-name buffer))
    (if diagnostics
        (dolist (diagnostic diagnostics)
          (let* ((range (lsp-diagnostic-range diagnostic))
                 (start (lsp-range-start range))
                 (severity (lsp-diagnostic-severity diagnostic))
                 (source (lsp-diagnostic-source diagnostic)))
            (format output
                    "~D:~D ~A~@[ [~A]~]~@[ (~A)~]~%"
                    (1+ (lsp-position-line start))
                    (1+ (lsp-position-character start))
                    (lsp-diagnostic-message diagnostic)
                    (and severity
                         (lsp-diagnostic-severity-name severity))
                    source)))
        (write-line "No diagnostics." output))))

(defun %lsp-error-message (session)
  (or (lsp-session-last-error session) "unknown LSP error"))

(defun lsp-start ()
  "Prompt for an LSP command and start a session for the selected buffer."
  (loom/application:with-prompts
      (minibuffer (editor-state-minibuffer *editor-state*)
                       :on-cancel (minibuffer-message minibuffer "Quit"))
      ((command "LSP command: "))
    (if (zerop (length (string-trim '(#\Space #\Tab) command)))
        (minibuffer-message minibuffer "LSP command cannot be empty")
        (let* ((buffer (loom/application:%selected-buffer))
               (directory (%lsp-buffer-directory buffer))
               (root-uri (and directory (lsp-path-uri directory)))
               (new-session nil))
          (handler-case
              (progn
                (setf new-session
                      (make-lsp-session :command command
                                        :directory directory
                                        :root-uri root-uri))
                (lsp-session-start new-session)
                (let ((old-session
                        (editor-state-lsp-session *editor-state*)))
                  (setf (editor-state-lsp-session *editor-state*)
                        new-session)
                  (when old-session
                    (lsp-session-stop old-session)))
                (minibuffer-message minibuffer "LSP started."))
            (error (condition)
              (when new-session
                (lsp-session-stop new-session))
              (minibuffer-message
               minibuffer
               (format nil "LSP start failed: ~A" condition))))))))

(defun lsp-stop ()
  "Stop the current LSP session, if one exists."
  (let ((session (editor-state-lsp-session *editor-state*))
        (minibuffer (editor-state-minibuffer *editor-state*)))
    (if session
        (progn
          (lsp-session-stop session)
          (setf (editor-state-lsp-session *editor-state*) nil)
          (minibuffer-message minibuffer "LSP stopped."))
        (minibuffer-message minibuffer "No LSP session."))))

(defun lsp-diagnostics ()
  "Refresh and display diagnostics for the selected file-backed buffer."
  (let* ((session (editor-state-lsp-session *editor-state*))
         (buffer (loom/application:%selected-buffer))
         (minibuffer (editor-state-minibuffer *editor-state*)))
    (cond
      ((null session)
       (minibuffer-message minibuffer "No LSP session."))
      ((null (buffer-path buffer))
       (minibuffer-message minibuffer
                            "LSP diagnostics need a file-backed buffer."))
      (t
       (lsp-session-refresh session buffer)
       (if (lsp-session-last-error session)
           (minibuffer-message
            minibuffer
            (format nil "LSP error: ~A" (%lsp-error-message session)))
           (let ((diagnostics-buffer (%lsp-diagnostics-buffer)))
             (%replace-buffer-text
              diagnostics-buffer
              (%lsp-diagnostics-text
               buffer
               (lsp-session-diagnostics session buffer)))
             (loom/feature/window:window-set-buffer
              (loom/application:%selected-window)
              diagnostics-buffer)
             (minibuffer-message minibuffer "LSP diagnostics refreshed.")))))))
