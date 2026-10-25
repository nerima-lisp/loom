(asdf:defsystem "loom-feature-evaluation"
  :depends-on ("loom-core-buffer"
               "loom-core-editor-session"
               "loom-core-minibuffer"
               "loom-core-window-tree"
               "loom-core-command"
               "loom-feature-buffers")
  :serial t
  :components
  ((:module "src"
    :serial t
    :components
    ((:file "package")
     (:file "domain-evaluation")
     (:file "infrastructure-lisp-evaluator")
     (:file "application-commands-evaluation")
     (:file "command-specs-evaluation")))))

(asdf:defsystem "loom-feature-evaluation/test"
  :depends-on ("loom-feature-evaluation"
               "loom/test-support"
               "cl-weave")
  :serial t
  :components
  ((:module "t"
    :serial t
    :components
    ((:module "unit"
      :serial t
      :components
      ((:file "evaluation-test")
       (:file "evaluation-result-test")))))))
