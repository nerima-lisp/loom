(asdf:defsystem "loom-feature-lang-nix"
  :depends-on ("loom-feature-mode"
               "loom-feature-syntax-highlighting")
  :components ((:module "src"
                :serial t
                :components ((:file "package")))))

(asdf:defsystem "loom-feature-lang-nix/test"
  :depends-on ("loom-feature-lang-nix")
  :components ())
