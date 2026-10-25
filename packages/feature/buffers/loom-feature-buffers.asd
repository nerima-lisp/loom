(asdf:defsystem "loom-feature-buffers"
  :depends-on ("loom-core-buffer"
               "loom-core-editor-session"
               "loom-core-minibuffer"
               "loom-core-window-tree"
               "loom-core-command")
  :serial t
  :components
  ((:module "src"
    :serial t
    :components
    ((:file "package")
     (:file "domain-buffer-registry")
     (:file "application-commands-quit-buffer-list")
     (:file "application-window-buffer-support")
     (:file "application-commands-buffer")
     (:file "command-specs-buffers")))))

(asdf:defsystem "loom-feature-buffers/test"
  :depends-on ("loom-feature-buffers"
               "loom/test-support"
               "cl-weave")
  :serial t
  :components
  ((:file "t/unit/buffer-registry-test")
   (:file "t/integration/commands-switch-buffer-test")
   (:file "t/integration/commands-buffer-lifecycle-test")))
