(asdf:defsystem "loom-feature-lisp-structure"
  :depends-on ("loom-core-buffer"
               "loom-core-editor-session"
               "loom-core-window-tree"
               "loom-core-command"
               "loom-feature-kill-ring"
               "loom-feature-mode")
  :serial t
  :components
  ((:module "src"
    :serial t
    :components
    ((:file "package")
     (:file "application-sexp-syntax")
     (:file "application-sexp-motion-support")
     (:file "application-sexp-motion-tokens")
     (:file "application-sexp-motion")
     (:file "application-structural-editing-support")
     (:file "application-structural-editing")
     (:file "application-structural-editing-offsets")
     (:file "application-structural-editing-application")
     (:file "application-commands-sexp")
     (:file "application-commands-structural-editing")
     (:file "command-specs-sexp")
     (:file "command-specs-structural-editing")))))

(asdf:defsystem "loom-feature-lisp-structure/test"
  :depends-on ("loom-feature-lisp-structure" "loom/test-support" "cl-weave")
  :serial t
  :components
  ((:module "t"
    :serial t
    :components
    ((:module "unit"
      :serial t
      :components
      ((:file "sexp-motion-test")
       (:file "structural-editing-test")))
     (:module "integration"
      :serial t
      :components
      ((:file "commands-sexp-test")
       (:file "commands-structural-editing-test")))))))
