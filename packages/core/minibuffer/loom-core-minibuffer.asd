(asdf:defsystem "loom-core-minibuffer"
  :depends-on ("cl-tty-kit" "cl-history-kit")
  :serial t
  :components
  ((:module "src"
    :serial t
    :components
    ((:file "package")
     (:file "minibuffer")
     (:file "minibuffer-activation")
     (:file "minibuffer-history")
     (:file "minibuffer-completion")
     (:file "minibuffer-input")
     (:file "commands-prompts")))))

(asdf:defsystem "loom-core-minibuffer/test"
  :depends-on ("loom-core-minibuffer" "loom/test-support" "cl-tty-kit" "cl-history-kit")
  :serial t
  :components
  ((:module "t"
    :serial t
    :components
    ((:module "unit"
      :serial t
      :components
      ((:file "minibuffer-test")
       (:file "minibuffer-input-test-support")
       (:file "minibuffer-input-activation-test")
       (:file "minibuffer-input-history-test")
       (:file "minibuffer-input-completion-test")
       (:file "minibuffer-input-classification-test")))
     (:module "integration"
      :serial t
      :components
      ((:file "commands-minibuffer-test")))))))
