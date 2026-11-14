(asdf:defsystem "loom-feature-buffer-menu"
  :depends-on ("cl-tty-kit"
               "loom-core-buffer"
               "loom-core-window-tree"
               "loom-core-editor-session"
               "loom-core-minibuffer"
               "loom-core-command"
               "loom-feature-buffers"
               "loom-feature-files"
               "loom-feature-mode")
  :serial t
  :components
  ((:module "src"
    :serial t
    :components
    ((:file "package")
     (:file "domain-buffer-menu")
     (:file "application-buffer-menu-list")
     (:file "application-commands-buffer-menu")
     (:file "application-buffer-menu-key-input")
     (:file "command-specs-buffer-menu")))))

(asdf:defsystem "loom-feature-buffer-menu/test"
  :depends-on ("loom-feature-buffer-menu"
               "loom/test-support"
               "cl-weave")
  :serial t
  :components
  ((:file "t/unit/buffer-menu-format-test")
   (:file "t/integration/buffer-menu-commands-test")))
