(asdf:defsystem "loom-feature-files"
  :depends-on ("cl-host-kit"
               "cl-boundary-kit"
               "loom-core-package-bootstrap"
               "loom-core-buffer"
               "loom-core-window-tree"
               "loom-core-editor-session"
               "loom-core-minibuffer"
               "loom-core-command"
               "loom-feature-buffers"
               "loom-feature-mode")
  :serial t
  :components
  ((:module "src"
    :serial t
    :components
    ((:file "package")
     (:file "editor-state-recent-files")
     (:file "infrastructure-filesystem-native-paths")
     (:file "infrastructure-filesystem-native-io")
     (:file "infrastructure-buffer-filesystem")
     (:file "application-commands-file")
     (:file "application-commands-file-save")
     (:file "command-specs-file")
     (:file "command-specs-file-save")))))

(asdf:defsystem "loom-feature-files/test"
  :depends-on ("loom-feature-files"
               "loom/test-support"
               "cl-weave"
               "cl-host-kit"
               "cl-boundary-kit")
  :serial t
  :components
  ((:module "t"
    :serial t
    :components
    ((:module "unit"
      :serial t
      :components
      ((:file "editor-state-recent-files-test")))
     (:module "integration"
      :serial t
      :components
      ((:file "commands-editing-save-file-test")))))))
