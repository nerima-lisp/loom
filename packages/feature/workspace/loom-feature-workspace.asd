(asdf:defsystem "loom-feature-workspace"
  :depends-on ("loom-core-editor-session" "loom-core-minibuffer"
                                          "loom-core-window-tree"
                                          "loom-core-command")
  :serial t
  :components ((:module "src"
                        :serial
                        t
                        :components
                        ((:file "package") (:file "domain-workspace-support")
                         (:file "domain-workspace")
                         (:file "domain-workspace-navigation")
                         (:file "application-workspace-switch-support")
                         (:file "application-workspace-transition-support")
                         (:file "application-commands-workspace")
                         (:file "command-specs-workspace")))))

(asdf:defsystem "loom-feature-workspace/test"
  :depends-on ("loom-feature-workspace" "loom/test-support" "cl-weave")
  :serial t
  :components ((:module "t"
                        :serial
                        t
                        :components
                        ((:module "unit"
                                  :serial
                                  t
                                  :components
                                  ((:file "editor-state-workspace-test")
                                   (:file "workspace-test")
                                   (:file "workspace-navigation-test")))
                         (:module "integration"
                                  :serial
                                  t
                                  :components
                                  ((:file "workspace-test")))))))
