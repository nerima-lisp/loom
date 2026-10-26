(asdf:defsystem "loom-feature-file-tree"
  :depends-on ("loom-core-editor-session"
               "loom-core-minibuffer"
               "loom-core-command"
               "loom-feature-files"
               "cl-host-kit"
               "cl-boundary-kit"
               "cl-concurrent-kit"
               "loom-feature-mode")
  :serial t
  :components
  ((:module "src"
    :serial t
    :components
    ((:file "package")
     (:file "domain-file-tree")
     (:file "domain-file-tree-navigation")
     (:file "infrastructure-file-tree-directory-listing")
     (:file "infrastructure-filesystem-native-mutations")
     (:file "infrastructure-filesystem-native-delete")
     (:file "infrastructure-file-tree-filesystem-support")
     (:file "infrastructure-file-tree-filesystem")
     (:file "infrastructure-concurrent-runtime-state")
     (:file "infrastructure-concurrent-runtime-prefetch")
     (:file "infrastructure-concurrent-runtime-results")
     (:file "application-commands-file-tree")
     (:file "command-specs-file-tree")
     (:file "application-file-tree-runtime")))))

(asdf:defsystem "loom-feature-file-tree/test"
  :depends-on ("loom-feature-file-tree"
               "loom-feature-files"
               "loom/test-support"
               "cl-weave"
               "loom-core-buffer"
               "loom-core-editor-session"
               "loom-core-minibuffer"
               "loom-core-window-tree"
               "cl-host-kit"
               "cl-boundary-kit"
               "cl-concurrent-kit")
  :serial t
  :components
  ((:module "t"
    :serial t
    :components
    ((:module "unit"
      :serial t
      :components
      ((:file "filesystem-test-support")
       (:file "file-tree-test")
       (:file "file-tree-selection-test")
       (:file "filesystem-create-test")
       (:file "filesystem-delete-test")
       (:file "filesystem-directory-test")
       (:file "filesystem-listing-test")
       (:file "filesystem-rename-boundary-test")
       (:file "editor-state-recent-file-completion-test")))
     (:module "integration"
      :serial t
      :components
      ((:file "commands-editing-find-file-test")
       (:file "commands-file-tree-navigation-test")
       (:file "commands-file-tree-mutation-test")
       (:file "concurrent-runtime-test-support")
       (:file "concurrent-runtime-invalidation-test")
       (:file "concurrent-runtime-prefetch-test")
       (:file "concurrent-runtime-shutdown-test")
       (:file "concurrent-runtime-stale-invalidation-test")
       (:file "concurrent-runtime-stale-prime-test")
       (:file "concurrent-runtime-submission-test")))))))
