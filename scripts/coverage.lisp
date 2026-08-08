;;;; Generate an sb-cover HTML report for the loom/test suite.
;;;;
;;;; Usage:  sbcl --script scripts/coverage.lisp
;;;;
;;;; Mirrors nshell's scripts/coverage.lisp and run-tests.lisp's own
;;;; source-registry setup: inside `nix develop` the sibling systems
;;;; (cl-tty-kit, cl-host-kit, cl-history-kit, cl-prolog, cl-cli, cl-weave)
;;;; are already on the ASDF source registry; for a plain ghq checkout only
;;;; the sibling roots required by loom are registered. When
;;;; CL_SOURCE_REGISTRY is already set, those local roots are not prepended:
;;;; otherwise a dirty sibling checkout could shadow pinned Nix inputs.
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

(let* ((script (or *load-truename*
                   (error "*LOAD-TRUENAME* is NIL; run this file as a script")))
       (script-path (truename script))
       (script-directory (make-pathname :name nil
                                        :type nil
                                        :version nil
                                        :defaults script-path))
       (directory (pathname-directory script-directory))
       (root (make-pathname
              :directory (if (rest directory) (butlast directory) directory)
              :name nil
              :type nil
              :version nil
              :defaults script-directory))
       (root-directory (pathname-directory root))
       (parent (make-pathname
                :directory (if (rest root-directory)
                               (butlast root-directory)
                               root-directory)
                :name nil
                :type nil
                :version nil
                :defaults root))
       (sibling-names '("cl-tty-kit"
                        "cl-host-kit"
                        "cl-history-kit"
                        "cl-prolog"
                        "cl-cli"
                        "cl-regex-kit"
                        "cl-boundary-kit"
                        "cl-concurrent-kit"
                        "cl-weave"
                        "cl-date-kit"
                        "cl-codec-kit"
                        "cl-parser-kit"))
       (sibling-directories
         (mapcar (lambda (name)
                   (merge-pathnames
                    (format nil "~A/" name)
                    parent))
                 sibling-names))
       (source-registry (sb-ext:posix-getenv "CL_SOURCE_REGISTRY")))
  (asdf:initialize-source-registry
   `(:source-registry
     (:directory ,root)
     ,@(unless (and source-registry (plusp (length source-registry)))
         (mapcar (lambda (directory)
                   `(:directory ,directory))
                 sibling-directories))
     :inherit-configuration)))

(asdf:load-system "cl-host-kit")
(require :sb-cover)

(declaim (optimize sb-cover:store-coverage-data))

(defun loom-source-file-p (file root)
  "Return true when FILE belongs to Loom's own source tree."
  (host-kit:pathname-within-p
   (host-kit:ensure-pathname file)
   (merge-pathnames #P"src/" root)))

(let* ((script (or *load-truename*
                   (error "*LOAD-TRUENAME* is NIL; run this file as a script")))
       (root (host-kit:parent-directory-pathname
              (host-kit:pathname-directory-pathname (truename script))))
       (coverage-dir
         (host-kit:ensure-directory-pathname
          (or (host-kit:getenv "LOOM_COVERAGE_DIR")
              (merge-pathnames #P"loom-coverage/"
                               (host-kit:temporary-directory)))))
       (passed-p nil))
  (sb-cover:enable-coverage-logging)
  (setf asdf:*compile-file-warnings-behaviour* :warn
        asdf:*compile-file-failure-behaviour* :error)
  (unwind-protect
       (setf passed-p
             (handler-case
                 (sb-ext:with-timeout 1800
                   (asdf:load-system :loom/test :force :all)
                   ;; Drive the cl-weave suite for its coverage side effects;
                   ;; the report is produced regardless of pass/fail.
                   ;; Preserve RUN-TESTS' actual pass/fail return value.
                   (funcall (symbol-function (find-symbol "RUN-TESTS" :loom/test))))
                (sb-ext:timeout ()
                  (format *error-output* "~&loom/test: timed out after 1800s~%")
                  nil)))
    (sb-cover:report coverage-dir
                     :if-matches (lambda (file)
                                   (loom-source-file-p file root))))
  (sb-ext:exit :code (if passed-p 0 1)))
