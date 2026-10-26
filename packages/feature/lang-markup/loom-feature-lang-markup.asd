(asdf:defsystem "loom-feature-lang-markup"
  :depends-on ("loom-feature-mode" "loom-feature-syntax-highlighting"
                                   "cl-markdown-kit"
                                   "cl-org-kit")
  :components ((:file "src/package")))

(asdf:defsystem "loom-feature-lang-markup/test"
  :depends-on ("loom-feature-lang-markup" "loom/test-support" "cl-weave")
  :serial t
  :components ((:file "t/integration/markup-display-lines-test")))
