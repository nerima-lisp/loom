(in-package #:loom/feature/user-init)
(eval-when (:load-toplevel :execute)
  (loom/core/editor-session:register-cli-option :feature/user-init
                                                "--no-init"
                                                :switch))

(defvar *user-init-package-provider* nil)
(defun register-user-init-package-provider (owner function)
  "Register OWNER's provider for the package used to load user init.

FUNCTION is called without arguments and must return a package. Registering
again as OWNER replaces its provider; a different owner is rejected."
  (unless (functionp function)
    (error "User init package provider must be a function"))
  (when (and *user-init-package-provider*
             (not (equal (car *user-init-package-provider*) owner)))
    (error "User init package provider is already registered by ~S"
           (car *user-init-package-provider*)))
  (setf *user-init-package-provider* (cons owner function))
  function)
(defun %user-init-package ()
  (unless *user-init-package-provider*
    (error "User init package provider is not registered"))
  (let ((package (funcall (cdr *user-init-package-provider*))))
    (unless (packagep package)
      (error "User init package provider returned ~S, not a package"
             package))
    package))
(defun %configured-user-init-path (&optional (getenv (function host-kit:getenv)))
  "Return the explicit or conventional path for the user init file."
  (let ((override (funcall getenv "LOOM_INIT_FILE")))
    (if (and override (string/= override ""))
        (pathname override)
        (merge-pathnames #P".loom/init.lisp"
                         (user-homedir-pathname)))))

(defun load-user-init (&optional path)
  "Load PATH, or the configured user init file when PATH is NIL.

An absent file is a no-op and returns NIL. Existing files are loaded as
trusted Common Lisp code in the LOOM-USER package; errors intentionally
propagate to the startup handler."
  (let* ((candidate (or path (%configured-user-init-path)))
         (resolved (probe-file candidate)))
    (when resolved
      (let ((*package* (%user-init-package)))
        (load resolved :verbose nil :print nil))
      resolved)))
