(asdf:defsystem "loom-feature-mouse"
  :depends-on ("cl-tty-kit"
               "loom-core-buffer"
               "loom-core-command"
               "loom-core-editor-session"
               "loom-core-window-tree"
               "loom-feature-file-tree"
               "loom-feature-window")
  :serial t
  :components
  ((:module "src"
    :serial t
    :components
    ((:file "package")
     (:file "application-mouse")))))

(asdf:defsystem "loom-feature-mouse/test"
  :depends-on ("loom-feature-mouse")
  :components ())
