(asdf:defsystem "loom-feature-lang-web"
  :depends-on ("loom-feature-mode"
               "loom-feature-syntax-highlighting")
  :components ((:module "src"
                :serial t
                :components ((:file "package")))))

(asdf:defsystem "loom-feature-lang-web/test"
  :depends-on ("loom-feature-lang-web")
  :components ())
