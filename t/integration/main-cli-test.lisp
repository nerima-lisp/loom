;;;; t/integration/main-cli-test.lisp
(in-package #:loom/test)

(describe
  "MAIN CLI integration"
  (it
    "defines the expected application contract"
    (let* ((app loom::*loom-app*)
           (positionals (cl-cli:app-positionals app)))
      (expect (cl-cli:app-name app) :to-equal "loom")
      (expect (cl-cli:app-summary app)
              :to-equal "Terminal text editor with Emacs-like keybindings")
      (expect positionals :to-have-length 1)
      (expect (cl-cli:positional-key (first positionals)) :to-be :path)
      (expect (cl-cli:positional-required-p (first positionals)) :to-be nil)
      (expect (functionp (cl-cli:app-handler app)) :to-be-truthy)))
  (it
    "passes process arguments to cl-cli and exits successfully"
    (let* ((root (namestring
                  (asdf:system-source-directory (asdf:find-system "loom"))))
           (parent (host-kit:parent-directory-pathname (pathname root)))
           (program (or (host-kit:find-program "sbcl")
                        (error "SBCL is required for the MAIN child-process test")))
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
                       (namestring
                        (merge-pathnames
                         (format nil "~A/" name)
                         parent)))
                     sibling-names))
           (registry-directives
             (if (let ((source-registry (host-kit:getenv "CL_SOURCE_REGISTRY")))
                   (and source-registry (plusp (length source-registry))))
                 (format nil "(list :directory ~S)" root)
                 (format nil
                         "(list :directory ~S)~{ (list :directory ~S)~}"
                         root
                         sibling-directories)))
           (form (format nil
                         "(progn
                            (asdf:initialize-source-registry
                             (list :source-registry ~A
                                   :inherit-configuration))
                            (asdf:load-system \"loom\")
                            (setf sb-ext:*posix-argv*
                                  (list \"loom\" \"--version\"))
                            (funcall (symbol-function
                                      (find-symbol \"MAIN\" \"LOOM\"))))"
                         registry-directives))
           (result (host-kit:run-program
                    program
                    (list "--noinform" "--non-interactive"
                          "--eval" "(require :asdf)"
                          "--eval" form)
                    :timeout 60)))
      (expect (host-kit:process-result-timed-out-p result) :to-be nil)
      (expect (host-kit:process-result-exit-code result) :to-be 0)
      (expect (host-kit:process-result-stdout result) :to-contain "loom"))))
