(asdf:defsystem "loom-feature-user-init"
  :depends-on ("loom-core-command" "loom-core-editor-session"
               "cl-host-kit")
  :serial t
  :components
  ((:module "src"
    :serial t
    :components
    ((:file "package")
     (:file "infrastructure-user-init")
     (:file "application-user-configuration")))))

(asdf:defsystem "loom-feature-user-init/test"
  :depends-on ("loom-feature-user-init" "loom/test-support" "cl-weave"
               "cl-host-kit")
  :serial t
  :components
  ((:module "t"
    :serial t
    :components
    ((:module "integration"
      :serial t
      :components
      ((:file "user-init-test")))))))
