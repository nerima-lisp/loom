(asdf:defsystem "loom-feature-kill-ring"
  :depends-on ("loom-core-buffer" "loom-core-editor-session"
                                  "loom-core-minibuffer"
                                  "loom-core-window-tree"
                                  "loom-core-command")
  :serial t
  :components ((:file "src/package")
               (:file "src/application-editor-state-operations")
               (:file "src/application-commands-kill-support")
               (:file "src/application-commands-kill-region-support")
               (:file "src/application-commands-yank-support")
               (:file "src/application-commands-yank-pop-support")
               (:file "src/application-commands-kill-word-support")
               (:file "src/application-commands-kill-yank")
               (:file "src/command-specs-kill")
               (:file "src/command-specs-yank")))

(asdf:defsystem "loom-feature-kill-ring/test"
  :depends-on ("loom-feature-kill-ring" "loom/test-support" "cl-weave")
  :serial t
  :components ((:file "t/unit/editor-state-yank-reset-test")
               (:file "t/integration/kill-yank-test-support")
               (:file "t/integration/kill-yank-test")
               (:file "t/integration/kill-yank-region-test")
               (:file "t/integration/kill-yank-yank-test")))
