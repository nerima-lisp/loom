(asdf:defsystem "loom-feature-lang-markup"
  :depends-on ("cl-markdown-kit" "cl-org-kit")
  :components ())

(asdf:defsystem "loom-feature-lang-markup/test"
  :depends-on ("loom-feature-lang-markup")
  :components ())
