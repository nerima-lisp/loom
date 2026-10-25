(asdf:defsystem "loom-core-package-bootstrap"
  :depends-on ("loom-core-buffer" "loom-core-window-tree"
               "loom-core-editor-session" "loom-core-minibuffer")
  :serial t
  :components
  ((:module "bootstrap"
    :pathname "../../../"
    :serial t
    :components
    ((:file "packages/core/command/src/package")
     (:file "packages/feature/buffers/src/package")
     (:file "packages/feature/bookmark/src/package")
     (:file "src/package-exports")
     (:file "src/package-application")
     (:file "src/package")))))

(asdf:defsystem "loom-core-package-bootstrap/test"
  :depends-on ("loom-core-package-bootstrap" "loom/test-support")
  :components
  ((:file "t/unit/package-bootstrap-test")))
