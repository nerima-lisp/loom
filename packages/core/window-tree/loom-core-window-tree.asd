(asdf:defsystem "loom-core-window-tree"
  :depends-on ()
  :serial t
  :components
  ((:module "src"
    :serial t
    :components
    ((:file "package")
     (:file "domain-window")
     (:file "domain-window-support")
     (:file "domain-window-layout")
     (:file "domain-window-operations")
     (:file "domain-window-accessors")
     (:file "domain-window-deletion")))))

(asdf:defsystem "loom-core-window-tree/test"
  :depends-on ("loom-core-window-tree" "loom/test-support" "cl-weave")
  :serial t
  :components
  ((:module "t"
    :serial t
    :components
    ((:module "unit"
      :serial t
      :components
      ((:file "window-basic-test")
       (:file "window-delete-behavior-test")
       (:file "window-delete-node-test")
       (:file "window-delete-other-windows-test")
       (:file "window-layout-test")))))))
