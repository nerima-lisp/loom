(asdf:defsystem "loom-feature-search"
  :depends-on ("loom-core-buffer"
               "loom-core-editor-session"
               "loom-core-minibuffer"
               "loom-core-command"
               "cl-regex-kit")
  :serial t
  :components
  ((:file "src/package")
   (:file "src/domain-buffer-search")
   (:file "src/domain-isearch")
   (:file "src/application-commands-search")
   (:file "src/application-commands-isearch")
   (:file "src/command-specs-search")
   (:file "src/command-specs-isearch")))

(asdf:defsystem "loom-feature-search/test"
  :depends-on ("loom-feature-search" "loom/test-support" "cl-weave" "cl-tty-kit")
  :serial t
  :components
  ((:file "t/unit/isearch-test")
   (:file "t/integration/search-test-support")
   (:file "t/integration/commands-editing-isearch-test")
   (:file "t/integration/commands-editing-search-navigation-test")
   (:file "t/integration/commands-editing-search-replace-test")))
