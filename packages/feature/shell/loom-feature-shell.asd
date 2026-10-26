(asdf:defsystem "loom-feature-shell"
  :depends-on ("loom-core-buffer"
               "loom-core-editor-session"
               "loom-core-minibuffer"
               "loom-core-window-tree"
               "loom-core-command"
               "loom-feature-buffers"
               "cl-process-kit")
  :serial t
  :components
  ((:module "src"
    :serial t
    :components
    ((:file "package")
     (:file "domain-shell")
     (:file "infrastructure-shell")
     (:file "application-commands-shell")
     (:file "command-specs-shell")))))

(asdf:defsystem "loom-feature-shell/test"
  :depends-on ("loom-feature-shell"
               "loom/test-support"
               "cl-weave"
               "cl-process-kit")
  :serial t
  :components
  ((:file "t/unit/shell-test")))
