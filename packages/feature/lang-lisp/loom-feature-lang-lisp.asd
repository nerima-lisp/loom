(asdf:defsystem "loom-feature-lang-lisp"
  :depends-on ()
  :components ((:file "src/package")))

(asdf:defsystem "loom-feature-lang-lisp/test"
  :depends-on ("loom-feature-lang-lisp")
  :components ())
