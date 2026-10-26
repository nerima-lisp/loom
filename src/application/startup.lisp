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

(defvar *event-loop-render-function* nil)
(defvar *startup-load-user-init-function* nil)
(defvar *startup-renderer-invalidate-function* nil)

(defun %run-loom (startup-context &key
                                       (fd 0 fd-supplied-p)
                                       (render-frame-function
                                        *event-loop-render-function*))
  (let ((term (unless fd-supplied-p (host-kit:getenv "TERM"))))
    (when (and (not fd-supplied-p)
               (or (null term)
                   (string= term "")
                   (string-equal term "dumb")))
      (format *error-output*
              "~&Cannot start Loom: TERM is ~A; set TERM to a supported terminal type.~%"
              (if (and term (string= term ""))
                  "empty"
                  (or term "unset")))
      (finish-output *error-output*)
      (return-from %run-loom 1)))
  (let* ((requests
           (loom/core/editor-session:startup-context-file-requests
            startup-context))
         (request (first requests))
         (path
           (and request
                (loom/core/editor-session:startup-file-request-path request))))
    (multiple-value-bind (reason status)
        (handler-case
            (%call-with-loom-terminal-streams
             fd
             fd-supplied-p
             (lambda (terminal-fd input-stream output-stream)
               (let ((*standard-input* input-stream)
                     (*standard-output* output-stream))
                 (%call-with-started-editor-state
                  path
                  (lambda (state)
                    (declare (ignore state))
                    (%run-loom-session startup-context
                                       terminal-fd
                                       render-frame-function))
                  request
                  (rest requests)))))
          (cl-cli:cli-usage-error (condition)
            (error condition))
          (cl-cli:cli-invalid-positional-value (condition)
            (error 'cl-cli:cli-usage-error
                   :message
                   (cl-cli:cli-error-message condition)))
          (error (condition)
            (%log-loom-error condition)
            (values :runtime-error 1)))
      (if (member reason '(:runtime-error :abort) :test (function eq))
          1
          (handler-case
              (or (first
                   (loom/core/editor-session:run-session-hooks
                    :exit-status
                    (editor-state-session *editor-state*)
                    reason))
                  status)
            (error (condition)
              (%log-loom-error condition)
              1))))))
