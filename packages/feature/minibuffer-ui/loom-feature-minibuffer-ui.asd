(asdf:defsystem "loom-feature-minibuffer-ui"
  :depends-on ("loom-core-editor-session"
               "loom-core-minibuffer"
               "loom-feature-completion"
               "cl-tty-kit")
  :serial t
  :components
  ((:module "src"
    :serial t
    :components
    ((:file "package")))))

(asdf:defsystem "loom-feature-minibuffer-ui/test"
  :depends-on ("loom-feature-minibuffer-ui"
               "loom/test-support"
               "cl-weave")
  :serial t
  :components
  ((:module "t"
    :serial t
    :components
    ((:file "minibuffer-ui-render-test")))))
