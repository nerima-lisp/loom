(asdf:defsystem "loom-feature-window"
  :depends-on ("loom-core-buffer"
               "loom-core-editor-session"
               "loom-core-window-tree"
               "loom-core-command")
  :serial t
  :components
  ((:module "src"
    :serial t
    :components
    ((:file "package")
     (:file "application-commands-window")
     (:file "application-commands-window-scroll")
     (:file "command-specs-window")
     (:file "command-specs-window-scroll")))))

(asdf:defsystem "loom-feature-window/test"
  :depends-on ("loom-feature-window" "loom/test-support" "cl-weave")
  :serial t
  :components
  ((:module "t"
    :serial t
    :components
    ((:module "integration"
      :serial t
      :components
      ((:file "commands-window-test")))))))
