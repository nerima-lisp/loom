(asdf:defsystem "loom-core-editor-session"
  :depends-on ("loom-core-buffer" "loom-core-window-tree")
  :serial t
  :components
  ((:module "src"
    :serial t
    :components
    ((:file "package")
     (:file "domain-editor-session-slices")
     (:file "application-editor-state-support")
     (:file "application-editor-state-types")
     (:file "application-editor-state")
     (:file "application-session-hooks")
     (:file "application-session-extension-points")
     (:file "application-session-hit-test-clipboard")
     (:file "application-commands-movement-visual-lines")))))

(asdf:defsystem "loom-core-editor-session/test"
  :depends-on ("loom-core-editor-session" "loom/test-support")
  :serial t
  :components
  ((:module "t"
    :serial t
    :components
    ((:module "unit"
      :serial t
      :components
      ((:file "slice-state-registration-test")
       (:file "editor-state-test")
       (:file "editor-session-api-test")
       (:file "frame-snapshot-test")
       (:file "session-hook-test")
       (:file "session-hook-resize-test")))))))
