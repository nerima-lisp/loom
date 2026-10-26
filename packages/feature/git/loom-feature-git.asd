(asdf:defsystem "loom-feature-git"
  :depends-on ("cl-resilience-kit"
               "cl-vcs-kit"
               "loom-core-buffer"
               "loom-core-command"
               "loom-core-editor-session"
               "loom-core-minibuffer"
               "loom-core-window-tree"
               "loom-feature-buffers"
               "loom-feature-project")
  :serial t
  :components
  ((:module "src"
    :serial t
    :components
    ((:file "package")
     (:file "domain-git")
     (:file "infrastructure-git")
     (:file "application-commands-git-support")
     (:file "application-commands-git")
     (:file "command-specs-git")))))

(asdf:defsystem "loom-feature-git/test"
  :depends-on ("loom-feature-git"
               "loom/test-support"
               "cl-weave"
               "cl-vcs-kit"
               "cl-resilience-kit")
  :serial t
  :components
  ((:module "t"
    :serial t
    :components
    ((:module "unit"
      :serial t
      :components
      ((:file "git-test")
       (:file "git-file-operations-test")))))))
