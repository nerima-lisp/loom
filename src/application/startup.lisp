(in-package #:loom)

(defun loom-version ()
  "Return LOOM's version string from its own ASDF system definition -- the
single source of truth loom.asd's header comment and flake.nix's ASDVERSIONOF
both already rely on -- so CL-CLI's generated --version output cannot drift
from it."
  (let ((system (asdf:find-system "loom" nil)))
    (or (and system (asdf:component-version system)) "unknown")))

(eval-when (:load-toplevel :execute)
  (loom/feature/lsp:register-client-version-provider :root
                                                     (function loom-version)))

(defun %call-with-started-editor-state (path thunk
                                             &optional
                                             startup-request
                                             additional-file-requests)
  "Initialize *EDITOR-STATE*, start startup services, call THUNK, then stop services."
  (%initialize-editor-state path
                            (mapcar
                             #'loom/core/editor-session:startup-file-request-path
                             additional-file-requests))
  (when startup-request
    (let* ((window
            (loom/core/window-tree:window-tree-selected-window
             (editor-state-window-tree *editor-state*)))
           (buffer (loom/core/window-tree:window-buffer window)))
      (when (buffer-path buffer)
        (buffer-set-point buffer
                          (1-
                           (loom/core/editor-session:startup-file-request-line
                            startup-request))
                          (1-
                           (loom/core/editor-session:startup-file-request-column
                            startup-request))))))
  (call-with-editor-session (editor-state-session *editor-state*)
                            (lambda ()
                              (%enable-concurrent-file-tree *editor-state*)
                              (unwind-protect (funcall thunk *editor-state*)
                                (%shutdown-editor-services *editor-state*)))))

(defun %run-loom (startup-context &key (fd 0))
  (let* ((requests
          (loom/core/editor-session:startup-context-file-requests
           startup-context))
         (request (first requests))
         (path
          (and request
               (loom/core/editor-session:startup-file-request-path request))))
    (multiple-value-bind (reason status)
        (handler-case (%call-with-started-editor-state path
                                                       (lambda (state)
                                                         (declare (ignore state))
                                                         (%run-loom-session
                                                          startup-context
                                                          fd))
                                                       request
                                                       (rest requests))
          (cl-cli:cli-usage-error (condition)
            (error condition))
          (error (condition)
            (%log-loom-error condition)
            (values :runtime-error 1)))
      (if (eq reason :runtime-error)
          1
          (handler-case (or
                         (first
                          (loom/core/editor-session:run-session-hooks
                           :exit-status
                           (editor-state-session *editor-state*)
                           reason))
                         status)
            (error (condition)
              (%log-loom-error condition)
              1))))))
