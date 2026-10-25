(asdf:defsystem "loom-feature-mode"
  :depends-on ("loom-core-buffer"
               "loom-core-editor-session"
               "loom-core-minibuffer"
               "loom-core-window-tree"
               "loom-core-command")
  :serial t
  :components
  ((:file "src/package")
   (:file "src/domain-major-mode-keywords")
   (:file "src/domain-major-mode-definitions")
   (:file "src/domain-major-mode-registry-support")
   (:file "src/domain-major-mode")
   (:file "src/domain-major-mode-registry")
   (:file "src/domain-major-mode-path")
   (:file "src/application-major-mode-support")
   (:file "src/application-major-mode")
   (:file "src/application-major-mode-editing")
   (:file "src/command-specs-modes")
   (:file "src/command-specs-major-mode-editing")))

(asdf:defsystem "loom-feature-mode/test"
  :depends-on ("loom-feature-mode" "loom/test-support" "cl-weave")
  :serial t
  :components
  ((:file "t/unit/major-mode-test")
   (:file "t/unit/major-mode-extension-test")
   (:file "t/integration/major-mode-test")
   (:file "t/integration/major-mode-comment-line-test")
   (:file "t/integration/major-mode-keymap-dispatch-test")))
