(in-package #:loom/feature/lsp)

(progn
  (defstruct
      (lsp-session-registry-state
       (:constructor %make-lsp-session-registry-state))
    (sessions (make-hash-table :test #'equal) :type hash-table)
    (trusted-configurations nil)
    (failed-configurations nil))
  (defun %lsp-make-registry-state (session)
    (declare (ignore session))
    (%make-lsp-session-registry-state))
  (loom/core/editor-session:register-slice-state :feature/lsp
                                                 '%lsp-make-registry-state)
  (defun %lsp-session-registry (session)
    (loom/core/editor-session:editor-session-slice session :feature/lsp))
  (defun %lsp-path-key (path)
    (when path
      (namestring
       (handler-case (truename path)
         (file-error ()
           (pathname path))))))
  (defun %lsp-session-key (root-path language-id)
    (when (and root-path language-id)
      (list (%lsp-path-key root-path) language-id)))
  (defun lsp-session-for-buffer (editor-session buffer)
    (when
        (and editor-session
             (buffer-p buffer)
             (buffer-path buffer)
             (member :feature/lsp
                     (loom/core/editor-session:editor-session-slice-names
                      editor-session)))
      (let* ((key
              (%lsp-session-key (%lsp-root-for-buffer buffer)
                                (%lsp-language-id
                                 (loom/core/buffer:buffer-major-mode buffer))))
             (registry
              (lsp-session-registry-state-sessions
               (%lsp-session-registry editor-session)))
             (session (and key (gethash key registry))))
        (and session (not (lsp-session-closed-p session)) session))))
  (defun %lsp-root-for-buffer (buffer)
    (let ((path (buffer-path buffer)))
      (when path
        (multiple-value-bind (command discovered-root configuration identity)
            (lsp-discover-command path)
          (declare (ignore command configuration identity))
          (or discovered-root
              (loom/feature/project:project-find-root path)
              (make-pathname :name nil :type nil :defaults (pathname path)))))))
  (progn
    (defun %lsp-current-editor-session ()
      (or *editor-session*
          (and *editor-state*
               (loom/core/editor-session:editor-state-session *editor-state*))))
    (defun %lsp-current-buffer-session (buffer &optional (auto-start-p t))
      (let* ((editor-session (%lsp-current-editor-session))
             (lsp-enabled-p
              (and editor-session
                   (member :feature/lsp
                           (loom/core/editor-session:editor-session-slice-names
                            editor-session))))
             (registered
              (and lsp-enabled-p
                   (lsp-session-for-buffer editor-session buffer))))
        (or registered
            (and auto-start-p
                 lsp-enabled-p
                 (%lsp-auto-start-buffer editor-session buffer)))))
    (defun lsp-editor-session-background-work-p (editor-session)
      (let* ((lsp-enabled-p
              (and editor-session
                   (member :feature/lsp
                           (loom/core/editor-session:editor-session-slice-names
                            editor-session))))
             (registry
              (and lsp-enabled-p
                   (lsp-session-registry-state-sessions
                    (%lsp-session-registry editor-session)))))
        (and registry
             (loop for session being the hash-values of registry
                   thereis (not (lsp-session-closed-p session)))))))
  (defun %lsp-register-session (editor-session lsp-session)
    (let ((key
           (%lsp-session-key (lsp-session-root-path lsp-session)
                             (lsp-session-language-id lsp-session))))
      (when key
        (setf (gethash key
                       (lsp-session-registry-state-sessions
                        (%lsp-session-registry editor-session))) lsp-session))))
  (defun %lsp-unregister-session (editor-session lsp-session)
    (let* ((key
            (%lsp-session-key (lsp-session-root-path lsp-session)
                              (lsp-session-language-id lsp-session)))
           (registry
            (lsp-session-registry-state-sessions
             (%lsp-session-registry editor-session))))
      (when (and key (eq (gethash key registry) lsp-session))
        (remhash key registry)))
    lsp-session)
  (defun %lsp-configuration-trusted-p (editor-session identity)
    (and identity
         (member identity
                 (lsp-session-registry-state-trusted-configurations
                  (%lsp-session-registry editor-session))
                 :test
                 #'equal)))
  (defun %lsp-trust-configuration (editor-session identity)
    (when identity
      (pushnew identity
               (lsp-session-registry-state-trusted-configurations
                (%lsp-session-registry editor-session))
               :test
               #'equal))
    identity)
  (defun %lsp-autostart-failed-p (editor-session identity)
    (and identity
         (member identity
                 (lsp-session-registry-state-failed-configurations
                  (%lsp-session-registry editor-session))
                 :test
                 #'equal)))
  (defun %lsp-record-autostart-failure (editor-session identity)
    (when identity
      (pushnew identity
               (lsp-session-registry-state-failed-configurations
                (%lsp-session-registry editor-session))
               :test
               #'equal))
    identity)
  (defun %lsp-auto-start-buffer (editor-session buffer)
  (when (and (buffer-path buffer)
             (null (lsp-session-for-buffer editor-session buffer)))
    (multiple-value-bind (command root configuration identity)
        (lsp-discover-command (buffer-path buffer))
      (declare (ignore configuration))
      (when (and command
                 (%lsp-configuration-trusted-p editor-session identity)
                 (not (%lsp-autostart-failed-p editor-session identity)))
        (multiple-value-bind (session condition)
            (%lsp-start-session
             command root
             (%lsp-language-id
              (loom/core/buffer:buffer-major-mode buffer))
             identity editor-session)
          (when condition
            (%lsp-record-autostart-failure editor-session identity)
            (let ((minibuffer
                    (and *editor-state*
                         (loom/core/editor-session:editor-state-minibuffer
                          *editor-state*))))
              (when minibuffer
                (minibuffer-message
                 minibuffer
                 (format nil "LSP auto-start failed: ~A"
                         (%lsp-sanitized-error-text condition))))))
          session))))))
