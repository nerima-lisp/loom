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
;;;; CL_SOURCE_REGISTRY, and for a plain ghq checkout only the sibling roots
;;;; required by loom are registered. When CL_SOURCE_REGISTRY is already set,
;;;; those local roots are not prepended: otherwise a dirty sibling checkout
;;;; could shadow pinned Nix inputs.
;;;;
;;;; SB-EXT:WITH-TIMEOUT bounds the whole load-and-run: `flake.nix`'s
;;;; `checks.default` already has cl-nix-forge's own `timeoutSeconds`, but a
;;;; plain local `sbcl --script run-tests.lisp` has nothing else guarding it,
;;;; so a hung compile or an infinite loop in the suite would otherwise block
;;;; forever instead of failing loudly.

(require :asdf)

(let* ((script (or *load-truename*
                   (error "*LOAD-TRUENAME* is NIL; run this file as a script")))
       (script-path (truename script))
       (root (make-pathname :name nil
                            :type nil
                            :version nil
                            :defaults script-path))
       (directory (pathname-directory root))
       (parent (make-pathname
                :directory (if (rest directory) (butlast directory) directory)
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

;; Warn rather than abort on compile-file warnings: the suite's own
;; failures are the signal this script reports, and a style warning in a
;; dependency should not masquerade as a test failure.
(setf asdf:*compile-file-warnings-behaviour* :warn
      asdf:*compile-file-failure-behaviour* :error)
(let ((passed-p
        (handler-case
            (sb-ext:with-timeout 600
                (asdf:load-system "loom/test")
                (funcall (symbol-function (find-symbol "RUN-TESTS" :loom/test))))
          (sb-ext:timeout ()
            (format *error-output* "~&loom/test: timed out after 600s~%")
            nil))))
  (sb-ext:exit :code (if passed-p 0 1)))
