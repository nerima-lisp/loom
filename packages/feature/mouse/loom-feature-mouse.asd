(asdf:defsystem "loom-feature-mouse"
  :depends-on ()
  :components ((:module "src" :serial t :components ((:file "package")))))

(asdf:defsystem "loom-feature-mouse/test"
  :depends-on ("loom-feature-mouse")
  :components ())
