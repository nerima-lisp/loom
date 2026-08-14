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
;;;; systems is still slower than a cached test run, so this is the entry
;;;; point most worth guarding against hanging forever when run via `nix
;;;; develop`'s `coverage` alias, which no external timeout wraps.

(require :asdf)

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
    (sb-ext:with-timeout 1800
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
          '(#P"src/" #P"packages/"))))

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
                   (sb-ext:with-timeout 1800
                     (progress "loading loom")
                     (asdf:load-system :loom)
                     (progress "loading loom/test")
                     (asdf:load-system :loom/test)
                     ;; cl-weave owns test execution and coverage collection;
                     ;; its no-test and empty-expression guards reject vacuous runs.
                     (progress "running tests")
                     (let* ((source-pathnames
                              (list (merge-pathnames #P"src/" root)
                                    (merge-pathnames #P"packages/" root)))
                            (run-all (%required-function "CL-WEAVE" "RUN-ALL"))
                            (coverage-statistics
                              (%required-function "CL-WEAVE" "COVERAGE-STATISTICS"))
                            (passed
                              (funcall run-all
                                       :reporter :spec
                                       :stream *standard-output*
                                       :pass-with-no-tests nil
                                       :timeout-ms 40000
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
                             (branch-total (getf statistics :branch-total)))
                         (unless (plusp expression-total)
                           (error "Coverage selected no source expressions under ~A."
                                  source-pathnames))
                         (format t "COVERAGE-EXPRESSIONS ~D/~D (~,2F%%)~%"
                                 expression-covered expression-total
                                 (* 100.0 (/ expression-covered expression-total)))
                         (format t "COVERAGE-BRANCHES ~D/~D (~,2F%%)~%"
                                 branch-covered branch-total
                                 (if (zerop branch-total)
                                     100.0
                                     (* 100.0 (/ branch-covered branch-total))))
                         passed)))
                 (sb-ext:timeout ()
                   (format *error-output* "~&loom/test: timed out after 1800s~%")
                   nil)))
      (progress "writing report")
      (sb-cover:report coverage-dir
                       :if-matches (lambda (file)
                                     (loom-source-file-p file root))))
    (progress (if passed-p "completed successfully" "completed with failures"))
    (sb-ext:exit :code (if passed-p 0 1))))
