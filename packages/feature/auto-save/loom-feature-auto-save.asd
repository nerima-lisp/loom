(asdf:defsystem "loom-feature-auto-save"
  :depends-on ("loom-core-buffer"
               "loom-core-editor-session"
               "loom-core-minibuffer"
               "loom-core-window-tree"
               "loom-core-command"
               "loom-feature-buffers")
  :serial t
  :components
  ((:module "src"
    :serial t
    :components
    ((:file "package")
     (:file "domain-auto-save")
     (:file "infrastructure-auto-save")
     (:file "application-auto-save-support")
     (:file "application-commands-auto-save")
     (:file "command-specs-auto-save")))))

(asdf:defsystem "loom-feature-auto-save/test"
  :depends-on ("loom-feature-auto-save"
               "loom/test-support"
               "cl-weave"
               "cl-host-kit"
               "loom-core-editor-session"
               "loom-core-window-tree")
  :serial t
  :components
  ((:file "t/unit/auto-save-test")))
