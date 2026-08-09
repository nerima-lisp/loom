;;;; packages/feature/user-init/src/infrastructure-user-init.lisp
;;;;
;;;; Infrastructure adapter for the optional user-owned startup file. The
;;;; loader only resolves the conventional path and establishes the public
;;;; user package; the application layer owns the extension API itself.
(in-package #:loom)

(defun %configured-user-init-path ()
  "Return the explicit or conventional path for the user init file."
  (let ((override (uiop:getenv "LOOM_INIT_FILE")))
    (if (and override (plusp (length override)))
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
      (let ((*package* (or (find-package '#:loom-user)
                           (error "LOOM-USER package is not available."))))
        (load resolved :verbose nil :print nil))
      resolved)))
