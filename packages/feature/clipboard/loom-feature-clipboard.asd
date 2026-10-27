(asdf:defsystem "loom-feature-clipboard"
  :depends-on ("loom-core-buffer"
               "loom-core-command"
               "loom-core-editor-session"
               "loom-core-minibuffer"
               "loom-core-window-tree"
               "loom-feature-kill-ring"
               "loom-feature-shell")
  :serial t
  :components
  ((:module "src"
    :serial t
    :components
    ((:file "package")
     (:file "infrastructure-clipboard")
     (:file "application-clipboard")
     (:file "command-specs-clipboard")))))

(asdf:defsystem "loom-feature-clipboard/test"
  :depends-on ("loom-feature-clipboard" "loom/test-support" "cl-weave")
  :components
  ((:file "t/unit/clipboard-test")))
