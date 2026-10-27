(in-package #:loom/feature/lsp)

(defun %lsp-buffer-directory (buffer)
  "Return BUFFER's containing directory, or NIL for an unsaved buffer."
  (let ((path (buffer-path buffer)))
    (and path (make-pathname :name nil :type nil :defaults (pathname path)))))

(progn
  (defun %lsp-error-message (session)
    (or (lsp-session-last-error session) "unknown LSP error"))

  (defun %lsp-sanitized-error-text (condition)
  (declare (ignore condition))
  "server could not be started or initialized")
)

(progn
  (defun %lsp-command-display (command)
    (if (listp command)
        (format nil "~{~A~^ ~}" command)
        (or command "")))

  (defun %lsp-command-prompt-string (discovered-command)
    (if discovered-command
        (format nil "LSP command [RET for ~A]: "
                (%lsp-command-display discovered-command))
        "LSP command: "))
)

(defun %normalize-lsp-command (typed-command discovered-command)
  (let ((trimmed (and typed-command
                      (string-trim '(#\Space #\Tab) typed-command))))
    (if (or (null trimmed) (string= trimmed ""))
        (values discovered-command nil)
        (let ((argv (%lsp-command-argv trimmed)))
          (values argv (null argv))))))

(progn
  (defun %lsp-discovery-unchanged-p
      (buffer command root configuration identity)
    (if (null identity)
        t
        (let ((path (buffer-path buffer)))
          (multiple-value-bind (current-command current-root
                               current-configuration current-identity)
              (and path (lsp-discover-command path))
            (and (equal identity current-identity)
                 (equal command current-command)
                 (equal (and root (namestring root))
                        (and current-root (namestring current-root)))
                 (equal (and configuration (namestring configuration))
                        (and current-configuration
                             (namestring current-configuration))))))))

  (defun %lsp-confirm-discovered-command
      (command root configuration buffer minibuffer &optional identity)
    (let* ((window (loom/core/window-tree:window-tree-selected-window
                    (editor-state-window-tree *editor-state*)))
           (scroll-line (loom/core/window-tree:window-scroll-line window))
           (scroll-column (loom/core/window-tree:window-scroll-column window))
           (scroll-sub-row (loom/core/window-tree:window-scroll-sub-row window))
           (review (make-buffer
                    :name "*LSP command review*"
                    :initial-content
                    (format nil
                            "Discovered LSP command~%PageDown/C-v: next; PageUp/M-v: previous~%Config: ~A~%Directory: ~A~%Command: ~A~%"
                            configuration root (%lsp-command-display command)))))
      (buffer-set-truncate-lines review nil)
      (buffer-set-read-only review t)
      (loom/core/window-tree:window-set-buffer window review)
      (labels ((restore-buffer ()
                 (loom/core/window-tree:window-set-buffer window buffer)
                 (setf (loom/core/window-tree:window-scroll-line window)
                       scroll-line
                       (loom/core/window-tree:window-scroll-column window)
                       scroll-column
                       (loom/core/window-tree:window-scroll-sub-row window)
                       scroll-sub-row))
               (review-key (key-event)
                 (let* ((descriptor
                          (loom/core/command:key-event->descriptor key-event))
                        (movement
                          (cond
                            ((or (equal descriptor '(nil . :page-down))
                                 (equal descriptor '((:control) . #\v)))
                             #'next-visual-line-once)
                            ((or (equal descriptor '(nil . :page-up))
                                 (equal descriptor '((:alt) . #\v)))
                             #'previous-visual-line-once))))
                   (when movement
                     (dotimes
                         (row (max 1
                                   (1- (loom/core/window-tree:window-height
                                        window))))
                       (funcall movement))
                     t))))
        (loom/core/minibuffer:minibuffer-activate
         minibuffer "Run discovered LSP command? Type yes: "
         :on-key #'review-key
         :on-cancel
         (lambda ()
           (restore-buffer)
           (loom/core/minibuffer:minibuffer-message minibuffer "Quit"))
         :on-confirm
         (lambda (answer)
           (restore-buffer)
           (cond
             ((not (string= answer "yes"))
              (loom/core/minibuffer:minibuffer-message
               minibuffer "LSP start cancelled."))
             ((not (%lsp-discovery-unchanged-p
                    buffer command root configuration identity))
              (loom/core/minibuffer:minibuffer-message
               minibuffer "LSP config changed; review again."))
             (t
              (let ((editor-session
                      (or loom/core/editor-session:*editor-session*
                          (loom/core/editor-session:editor-state-session
                           *editor-state*))))
                (%lsp-trust-configuration editor-session identity)
                (%lsp-start-with-command
                 command root buffer minibuffer identity)))))))
)
))

(defun %install-lsp-session (editor-session new-session)
  (let* ((key (%lsp-session-key (lsp-session-root-path new-session)
                                (lsp-session-language-id new-session)))
         (registry (lsp-session-registry-state-sessions
                    (%lsp-session-registry editor-session)))
         (old-session (and key (gethash key registry))))
    (when (and old-session (not (eq old-session new-session)))
      (%lsp-unregister-session editor-session old-session)
      (lsp-session-stop old-session))
    (%lsp-register-session editor-session new-session)
    (when *editor-state*
      (setf (loom/core/editor-session:editor-state-lsp-session
             *editor-state*)
            new-session))
    new-session))

(defun %lsp-start-session
    (command directory language-id config-identity editor-session)
  (let ((new-session nil)
        (root-uri (and directory (lsp-path-uri directory)))
        (process-command (%lsp-command-display command)))
    (handler-case
        (progn
          (setf new-session
                (make-lsp-session
                 :command process-command
                 :directory directory
                 :root-uri root-uri
                 :root-path directory
                 :language-id language-id
                 :config-identity config-identity))
          (lsp-session-start new-session)
          (%install-lsp-session editor-session new-session)
          (values new-session nil))
      (error (condition)
        (when new-session
          (lsp-session-stop new-session))
        (values nil condition)))))

(defun %lsp-report-start-result (minibuffer session condition) (declare (ignore session)) (if condition (loom/core/minibuffer:minibuffer-message minibuffer (format nil "LSP start failed: ~A" (if (typep condition (quote lsp-transport-send-exit-error)) (format nil "server exited with status ~D" (lsp-transport-send-exit-status condition)) condition))) (loom/core/minibuffer:minibuffer-message minibuffer "LSP started.")))
