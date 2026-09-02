;;;; Generate a cl-weave/SB-COVER HTML report for the loom/test suite.
;;;;
;;;; Usage:  sbcl --script scripts/coverage.lisp
;;;;
;;;; Mirrors nshell's scripts/coverage.lisp and run-tests.lisp's own
;;;; source-registry setup: inside `nix develop` the sibling systems
;;;; (cl-tty-kit, cl-host-kit, cl-history-kit, cl-prolog-kit, cl-cli, cl-weave)
;;;; are already on the ASDF source registry; for a plain ghq checkout only
;;;; the sibling roots required by loom are registered. When
;;;; CL_SOURCE_REGISTRY is already set, those local roots are not prepended:
;;;; otherwise a dirty sibling checkout could shadow pinned Nix inputs.
;;;;
;;;; Load Loom after SB-COVER is enabled so its local source components are
;;;; compiled with instrumentation. Do not use ASDF's :force :all here:
;;;; dependencies are immutable Nix store paths, so forcing the complete graph
;;;; would try to write FASLs beside those dependencies and fail with EACCES.
;;;;
;;;; SB-EXT:WITH-TIMEOUT bounds the whole run at 1800s, matching
;;;; `flake.nix`'s own `checks.default` `timeoutSeconds`: forcing both Loom
;;;; systems is still slower than a cached test run. The development alias
;;;; adds an OS-level timeout as well, so a stuck child process cannot outlive
;;;; the Lisp-level guard.

(require :asdf)

(defconstant +coverage-timeout-seconds+ 1800)
(defconstant +coverage-test-timeout-ms+ 120000)
(defconstant +coverage-source-directories+ '(#P"src/" #P"packages/"))

(defun %required-function (package-name symbol-name)
  (let ((symbol (find-symbol symbol-name package-name)))
    (unless (and symbol (fboundp symbol))
      (error "Package ~A does not provide function ~A."
             package-name symbol-name))
    (symbol-function symbol)))

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
                        "cl-prolog-kit"
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

(handler-case
    (sb-ext:with-timeout +coverage-timeout-seconds+
      (asdf:load-system "cl-host-kit")
      (require :sb-cover))
  (sb-ext:timeout ()
    (error "Timed out while loading coverage dependencies.")))

(declaim (optimize sb-cover:store-coverage-data))

(defun loom-source-file-p (file root)
  "Return true when FILE belongs to Loom's source or package trees."
  (let ((pathname (host-kit:ensure-pathname file)))
    (some (lambda (directory)
            (host-kit:pathname-within-p
             pathname
             (merge-pathnames directory root)))
          +coverage-source-directories+)))

(defun %coverage-minimum (name)
  "Return the optional percentage threshold named by environment NAME."
  (let ((value (sb-ext:posix-getenv name)))
    (when (and value (plusp (length value)))
      (let ((minimum
              (with-input-from-string (stream value)
                (let ((*read-eval* nil)
                      (eof (gensym "EOF")))
                  (let ((number (read stream nil eof))
                        (trailing (read stream nil eof)))
                    (if (eq trailing eof) number nil))))))
        (unless (and (realp minimum) (<= 0 minimum 100))
          (error "~A must be a percentage between 0 and 100, got ~S."
                 name value))
        minimum))))

(defun %coverage-source-pathnames (root)
  (mapcar (lambda (directory)
            (merge-pathnames directory root))
          +coverage-source-directories+))

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
  (flet ((progress (message)
           (format *error-output* "~&loom/coverage: ~A~%" message)
           (finish-output *error-output*)))
    (progress "enabling coverage logging")
    (sb-cover:enable-coverage-logging)
    (setf asdf:*compile-file-warnings-behaviour* :warn
          asdf:*compile-file-failure-behaviour* :error)
    (unwind-protect
         (setf passed-p
               (handler-case
                   (sb-ext:with-timeout +coverage-timeout-seconds+
                     (progress "loading loom")
                     ;; Recompile Loom's local components so SB-COVER sees
                     ;; the current source instead of an ASDF-cached FASL.
                     (asdf:load-system :loom :force t)
                     (progress "loading loom/test")
                     (asdf:load-system :loom/test)
                     ;; cl-weave owns test execution and coverage collection;
                     ;; its no-test and empty-expression guards reject vacuous runs.
                     (progress "running tests")
                     (let* ((source-pathnames
                           (%coverage-source-pathnames root))
                            (run-all (%required-function "CL-WEAVE" "RUN-ALL"))
                            (coverage-statistics
                              (%required-function "CL-WEAVE" "COVERAGE-STATISTICS"))
                            (passed
                              (funcall run-all
                                       :reporter :spec
                                       :stream *standard-output*
                                       :pass-with-no-tests nil
                                       ;; Coverage instrumentation makes the
                                       ;; subprocess-based CLI integration
                                       ;; test substantially slower than the
                                       ;; normal test run.
                                       :timeout-ms +coverage-test-timeout-ms+
                                       ;; Coverage is intentionally deterministic:
                                       ;; subprocess-backed tests must not race
                                       ;; with parallel workers during teardown.
                                       :max-workers 1
                                       :coverage t
                                       :coverage-include-pathnames source-pathnames))
                            (statistics
                              (funcall coverage-statistics
                                       :include-pathnames source-pathnames)))
                       (unless passed
                         (error "cl-weave reported a test failure while collecting coverage."))
                       (let ((expression-covered (getf statistics :expression-covered))
                             (expression-total (getf statistics :expression-total))
                             (branch-covered (getf statistics :branch-covered))
                             (branch-total (getf statistics :branch-total))
                             (expression-minimum (%coverage-minimum
                                                  "LOOM_COVERAGE_MIN_EXPRESSIONS"))
                             (branch-minimum (%coverage-minimum
                                              "LOOM_COVERAGE_MIN_BRANCHES")))
                         (unless (plusp expression-total)
                           (error "Coverage selected no source expressions under ~A."
                                  source-pathnames))
                         (format t "COVERAGE-EXPRESSIONS ~D/~D (~,2F%)~%"
                                 expression-covered expression-total
                                 (* 100.0 (/ expression-covered expression-total)))
                         (format t "COVERAGE-BRANCHES ~D/~D (~,2F%)~%"
                                 branch-covered branch-total
                                 (if (zerop branch-total)
                                     100.0
                                     (* 100.0 (/ branch-covered branch-total))))
                         (let ((expression-rate
                                 (* 100.0 (/ expression-covered expression-total)))
                               (branch-rate
                                 (if (zerop branch-total)
                                     100.0
                                     (* 100.0 (/ branch-covered branch-total)))))
                           (when (and expression-minimum
                                      (< expression-rate expression-minimum))
                             (error "Expression coverage ~,2F%% is below minimum ~,2F%%."
                                    expression-rate expression-minimum))
                           (when (and branch-minimum
                                      (< branch-rate branch-minimum))
                             (error "Branch coverage ~,2F%% is below minimum ~,2F%%."
                                    branch-rate branch-minimum)))
                         passed)))
                 (sb-ext:timeout ()
                   (format *error-output* "~&loom/test: timed out after ~Ds~%"
                           +coverage-timeout-seconds+)
                   nil)))
      (progress "writing report")
      (sb-cover:report coverage-dir
                       :if-matches (lambda (file)
                                     (loom-source-file-p file root))))
    (let ((index (merge-pathnames #P"cover-index.html" coverage-dir)))
      (unless (probe-file index)
        (error "Coverage report did not produce ~A." index))
      (progress (format nil "report available at ~A" index)))
    (progress (if passed-p "completed successfully" "completed with failures"))
    (sb-ext:exit :code (if passed-p 0 1))))
