;;;; Generate an sb-cover HTML report for the loom/test suite.
;;;;
;;;; Usage:  sbcl --script scripts/coverage.lisp
;;;;
;;;; Mirrors nshell's scripts/coverage.lisp and run-tests.lisp's own
;;;; source-registry setup: inside `nix develop` the sibling systems
;;;; (cl-tty-kit, cl-host-kit, cl-history-kit, cl-prolog, cl-cli, cl-weave)
;;;; are already on the ASDF source registry; for a plain ghq checkout the
;;;; parent directory tree is registered too, so ../cl-tty-kit etc. are
;;;; found automatically. An explicit CL_SOURCE_REGISTRY still wins, because
;;;; the existing configuration is inherited rather than replaced.
;;;;
;;;; :force :all is required, not :force t: :force t only forces recompiling
;;;; loom/test itself, leaving loom (src/) loaded from cached, uninstrumented
;;;; fasls -- sb-cover's coverage proclamation never reaches src/, and the
;;;; report silently covers only test files.
;;;;
;;;; SB-EXT:WITH-TIMEOUT bounds the whole run at 1800s, matching
;;;; `flake.nix`'s own `checks.default` `timeoutSeconds`: :FORCE :ALL means
;;;; every sibling dependency recompiles from scratch under sb-cover
;;;; instrumentation, so this is the slowest entry point in the repo and the
;;;; one most worth guarding against hanging forever when run via `nix
;;;; develop`'s `coverage` alias, which no external timeout wraps.

(require :asdf)
(require :sb-cover)

(declaim (optimize sb-cover:store-coverage-data))

(defun loom-source-file-p (file root)
  "Return true when FILE belongs to Loom's own source tree."
  (uiop:subpathp
   (uiop:parse-native-namestring file)
   (merge-pathnames #P"src/" root)))

(let* ((root (truename #P"./"))
       (parent (uiop:pathname-parent-directory-pathname root))
       (coverage-dir
         (uiop:ensure-directory-pathname
          (or (uiop:getenv "LOOM_COVERAGE_DIR")
              (merge-pathnames #P"loom-coverage/"
                               (uiop:temporary-directory)))))
       (passed-p nil))
  (asdf:initialize-source-registry
   `(:source-registry
     (:directory ,root)
     (:tree ,parent)
     :inherit-configuration))
  (sb-cover:enable-coverage-logging)
  (unwind-protect
       (setf passed-p
             (handler-case
                 (sb-ext:with-timeout 1800
                   (asdf:load-system :loom/test :force :all)
                   ;; Drive the cl-weave suite for its coverage side effects;
                   ;; the report is produced regardless of pass/fail.
                   ;; Preserve RUN-TESTS' actual pass/fail return value.
                   (uiop:symbol-call :loom/test '#:run-tests))
               (sb-ext:timeout ()
                 (format *error-output* "~&loom/test: timed out after 1800s~%")
                 nil)
               (error (condition)
                 (format *error-output* "~&loom/test failed: ~A~%" condition)
                 nil)))
    (sb-cover:report coverage-dir
                     :if-matches (lambda (file)
                                   (loom-source-file-p file root))))
  (sb-ext:exit :code (if passed-p 0 1)))
