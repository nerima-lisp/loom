(asdf:defsystem "loom-feature-lifecycle"
  :depends-on ("loom-core-buffer" "loom-core-editor-session"
                                  "loom-core-minibuffer"
                                  "loom-core-window-tree"
                                  "loom-core-command"
                                  "loom-feature-buffers"
                                  "loom-feature-files"
                                  "cl-prolog-kit")
  :serial t
  :components ((:module "src"
                        :serial
                        t
                        :components
                        ((:file "package") (:file "application-commands-quit")
                         (:file "command-specs-quit")))))

(asdf:defsystem "loom-feature-lifecycle/test"
  :depends-on ("loom-feature-lifecycle" "loom/test-support"
                                        "cl-weave"
                                        "cl-host-kit")
  :serial t
  :components ((:module "t"
                        :serial
                        t
                        :components
                        ((:module "integration"
                                  :serial
                                  t
                                  :components
                                  ((:file "commands-editing-quit-test")
                                   (:file "commands-quit-test")))))))
