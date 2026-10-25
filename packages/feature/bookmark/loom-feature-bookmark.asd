(asdf:defsystem "loom-feature-bookmark"
  :depends-on ("loom-core-buffer"
               "loom-core-editor-session"
               "loom-core-minibuffer"
               "loom-core-window-tree"
               "loom-core-command"
               "loom-feature-buffers"
               "loom-feature-files"
               "cl-host-kit")
  :serial t
  :components
  ((:module "src"
    :serial t
    :components
    ((:file "package")
     (:file "domain-editor-bookmark")
     (:file "application-commands-bookmark-support")
     (:file "commands-bookmark")
     (:file "command-specs-bookmark")))))

(asdf:defsystem "loom-feature-bookmark/test"
  :depends-on ("loom-feature-bookmark"
               "loom-feature-file-tree"
               "loom/test-support"
               "cl-weave"
               "cl-host-kit")
  :serial t
  :components
  ((:file "t/unit/editor-state-bookmarks-test")
   (:file "t/integration/commands-bookmark-test")))
