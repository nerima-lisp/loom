(asdf:defsystem "loom-feature-completion"
  :depends-on ("loom-core-buffer"
               "loom-core-command"
               "loom-core-editor-session"
               "loom-core-window-tree")
  :serial t
  :components
  ((:module "src"
    :serial t
    :components
    ((:file "package")
     (:file "application-completion-popup")
     (:file "application-completion-popup-input")))))

(asdf:defsystem "loom-feature-completion/test"
  :depends-on ("loom-feature-completion" "loom/test-support" "cl-weave")
  :serial t
  :components
  ((:module "t"
    :serial t
    :components
    ((:module "unit"
      :serial t
      :components
      ((:file "completion-popup-test")))))))
