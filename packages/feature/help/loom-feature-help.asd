(asdf:defsystem "loom-feature-help"
  :depends-on ("loom-core-command"
               "loom-core-editor-session"
               "loom-core-minibuffer"
               "loom-feature-buffers"
               "loom-feature-mode")
  :serial t
  :components
  ((:module "src"
    :serial t
    :components
    ((:file "package")
     (:file "application-commands-help-command")
     (:file "command-specs-help")))))

(asdf:defsystem "loom-feature-help/test"
  :depends-on ("loom-feature-help" "loom/test-support" "cl-weave")
  :serial t
  :components
  ((:module "t"
    :serial t
    :components
    ((:module "integration"
      :serial t
      :components
      ((:file "commands-help-test")))))))
