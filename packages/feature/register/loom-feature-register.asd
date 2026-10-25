(asdf:defsystem "loom-feature-register"
  :depends-on ("loom-core-buffer"
               "loom-core-editor-session"
               "loom-core-minibuffer"
               "loom-core-window-tree"
               "loom-core-command")
  :serial t
  :components
  ((:module "src"
    :serial t
    :components
    ((:file "package")
     (:file "domain-register")
     (:file "application-commands-register")
     (:file "command-specs-register")))))

(asdf:defsystem "loom-feature-register/test"
  :depends-on ("loom-feature-register" "loom/test-support" "cl-weave")
  :serial t
  :components
  ((:file "t/unit/register-test")
   (:file "t/integration/register-test")))
