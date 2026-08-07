;;;; run-tests.lisp
;;;;
;;;; Lisp-level entry point for the loom test suite.
;;;;
;;;; Usage:  sbcl --script run-tests.lisp
;;;;
;;;; This is the single entry point the org standard requires at the
;;;; repository root. It is what `checks.default` and `apps.test` in
;;;; flake.nix invoke, so the hermetic Nix check and a plain local run
;;;; execute exactly the same code path rather than two hand-rolled `--eval`
;;;; chains that drift apart.
;;;;
;;;; Dependency resolution mirrors nshell's run-tests.lisp: inside `nix
;;;; develop` or the Nix sandbox the systems are already on
;;;; CL_SOURCE_REGISTRY, and for a plain ghq checkout the parent directory
;;;; tree is registered so sibling checkouts (../cl-tty-kit, ../cl-host-kit,
;;;; ../cl-history-kit, ../cl-weave, ...) are found automatically. An
;;;; explicit CL_SOURCE_REGISTRY still wins, because the existing
;;;; configuration is inherited rather than replaced.
;;;;
;;;; SB-EXT:WITH-TIMEOUT bounds the whole load-and-run: `flake.nix`'s
;;;; `checks.default` already has cl-nix-forge's own `timeoutSeconds`, but a
;;;; plain local `sbcl --script run-tests.lisp` has nothing else guarding it,
;;;; so a hung compile or an infinite loop in the suite would otherwise block
;;;; forever instead of failing loudly.

(require :asdf)

(let* ((root (truename #P"./"))
       (parent (uiop:pathname-parent-directory-pathname root)))
  (asdf:initialize-source-registry
   `(:source-registry
     (:directory ,root)
     (:tree ,parent)
     :inherit-configuration))
  ;; Warn rather than abort on compile-file warnings: the suite's own
  ;; failures are the signal this script reports, and a style warning in a
  ;; dependency should not masquerade as a test failure.
  (setf asdf:*compile-file-warnings-behaviour* :warn
        asdf:*compile-file-failure-behaviour* :warn)
  (let ((passed-p
          (handler-case
              (sb-ext:with-timeout 600
                (asdf:load-system "loom/test")
                (uiop:symbol-call :loom/test '#:run-tests))
            (sb-ext:timeout ()
              (format *error-output* "~&loom/test: timed out after 600s~%")
              nil)
            (error (condition)
              (format *error-output* "~&loom/test failed: ~A~%" condition)
              nil))))
    (sb-ext:exit :code (if passed-p 0 1))))
