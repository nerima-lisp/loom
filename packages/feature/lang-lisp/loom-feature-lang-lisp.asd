(asdf:defsystem "loom-feature-lang-lisp"
  :depends-on ("loom-feature-mode" "loom-feature-lisp-structure"
                                   "loom-core-buffer")
  :serial t
  :components ((:file "src/package") (:file "src/lisp-indentation")))

(asdf:defsystem "loom-feature-lang-lisp/test"
  :depends-on ("loom-feature-lang-lisp")
  :components ())
