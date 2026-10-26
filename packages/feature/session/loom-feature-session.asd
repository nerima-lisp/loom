(asdf:defsystem "loom-feature-session"
  :depends-on ("loom-core-window-tree"
               "loom-core-buffer"
               "loom-core-editor-session"
               "loom-core-minibuffer"
               "loom-core-command"
               "loom-feature-bookmark"
               "loom-feature-buffers"
               "loom-feature-workspace"
               "loom-feature-file-tree"
               "cl-host-kit")
  :serial t
  :components
  ((:module "src"
    :serial t
    :components
    ((:file "package")
     (:file "domain-session-snapshot")
     (:file "domain-session-predicates")
     (:file "domain-session-validation-metadata")
     (:file "domain-session-validation-layout")
     (:file "domain-session-validation")
     (:file "infrastructure-session-codec-plist")
     (:file "infrastructure-session-codec")
     (:file "infrastructure-session-store")
     (:file "application-session-bookmarks")
     (:file "application-session-workspaces")
     (:file "application-session-snapshot")
     (:file "application-session-restore")
     (:file "application-commands-session")
     (:file "command-specs-session")))))

(asdf:defsystem "loom-feature-session/test"
  :depends-on ("loom-feature-session"
               "loom/test-support"
               "cl-weave"
               "cl-host-kit")
  :serial t
  :components
  ((:file "t/integration/session-test-support")
   (:file "t/integration/session-store-roundtrip-test")
   (:file "t/integration/session-store-buffer-validation-test")
   (:file "t/integration/session-store-layout-validation-test")
   (:file "t/integration/session-store-envelope-test")
   (:file "t/integration/session-application-test")
   (:file "t/integration/session-workspace-application-test")
   (:file "t/integration/session-command-test")))
