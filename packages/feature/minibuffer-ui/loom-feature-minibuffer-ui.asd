(asdf:defsystem "loom-feature-minibuffer-ui"
  :depends-on ("loom-core-minibuffer"
               "loom-feature-completion")
  :serial t
  :components
  ((:module "src"
    :serial t
    :components
    ((:file "package")))))

(asdf:defsystem "loom-feature-minibuffer-ui/test"
  :depends-on ("loom-feature-minibuffer-ui")
  :serial t
  :components ())
