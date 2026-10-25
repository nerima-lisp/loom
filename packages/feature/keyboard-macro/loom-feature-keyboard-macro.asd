(asdf:defsystem "loom-feature-keyboard-macro"
  :depends-on ("loom-core-command"
               "loom-core-editor-session"
               "loom-core-minibuffer")
  :serial t
  :components ((:file "src/package")
               (:file "src/domain-keyboard-macro")
               (:file "src/application-commands-keyboard-macro")
               (:file "src/command-specs-keyboard-macro")))

(asdf:defsystem "loom-feature-keyboard-macro/test"
  :depends-on ("loom-feature-keyboard-macro" "loom/test-support" "cl-weave")
  :serial t
  :components ((:file "t/unit/keyboard-macro-test")
               (:file "t/unit/editor-state-keyboard-macro-state-test")
               (:file "t/integration/keyboard-macro-test")))
