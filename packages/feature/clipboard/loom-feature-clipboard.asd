(asdf:defsystem "loom-feature-clipboard"
  :depends-on ()
  :components ((:module "src" :serial t :components ((:file "package")))))

(asdf:defsystem "loom-feature-clipboard/test"
  :depends-on ("loom-feature-clipboard")
  :components ())
