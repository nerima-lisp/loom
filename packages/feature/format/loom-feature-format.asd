(asdf:defsystem "loom-feature-format"
  :depends-on ("loom-core-buffer"
               "loom-core-editor-session"
               "loom-core-minibuffer"
               "loom-core-window-tree"
               "loom-feature-shell"
               "loom-core-command")
  :serial t
  :components
  ((:module "src"
    :serial t
    :components
    ((:file "package")
     (:file "application-format-buffer")
     (:file "application-commands-format")
     (:file "command-specs-format")))))

(asdf:defsystem "loom-feature-format/test"
  :depends-on ("loom-feature-format"
               "loom/test-support"
               "cl-weave"
               "cl-host-kit"
               "loom-core-editor-session"
               "loom-core-minibuffer"
               "loom-feature-shell")
  :serial t
  :components
  ((:file "t/unit/format-test")))
