(asdf:defsystem "loom-feature-project"
  :depends-on ("loom-core-buffer"
               "loom-core-editor-session"
               "loom-core-minibuffer"
               "loom-core-window-tree"
               "loom-core-command"
               "loom-feature-buffers"
               "loom-feature-files"
               "loom-feature-file-tree")
  :serial t
  :components
  ((:module "src"
    :serial t
    :components
    ((:file "package")
     (:file "domain-project")
     (:file "infrastructure-project-filesystem")
     (:file "application-commands-project")
     (:file "command-specs-project")))))

(asdf:defsystem "loom-feature-project/test"
  :depends-on ("loom-feature-project"
               "loom/test-support"
               "cl-weave"
               "cl-host-kit")
  :serial t
  :components
  ((:file "t/unit/project-test")
   (:file "t/integration/project-test")
   (:file "t/integration/project-missing-root-test")))
