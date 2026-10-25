(asdf:defsystem "loom-core-command"
  :depends-on ("cl-json-kit" "cl-tty-kit"
               "loom-core-package-bootstrap"
               "loom-core-buffer" "loom-core-window-tree"
               "loom-core-editor-session" "loom-core-minibuffer")
  :serial t
  :components
  ((:module "kill-ring-command-support"
    :pathname "../../../packages/feature/kill-ring/src/"
    :serial t
    :components ((:file "application-commands-kill-word-support")))
   (:module "buffer-command-support"
    :pathname "../../../packages/core/buffer/src/"
    :serial t
    :components ((:file "application-commands-region-support")))
   (:module "src"
    :serial t
    :components
    ((:file "domain-prefix-argument")
     (:file "domain-keymap-descriptor")
     (:file "domain-keymap")
     (:file "domain-keymap-state")
     (:file "domain-key-event-descriptor")
     (:file "command-registry-forms")
     (:file "command-registry-build")
     (:file "command-registry")
     (:file "command-registry-registration")
     (:file "command-repeat")
     (:file "command-invocation")
     (:file "application-commands-prefix-argument-support")
     (:file "application-commands-prefix-argument")
     (:file "application-word-motion")
     (:file "application-commands-movement-support")
     (:file "application-commands-kill")
     (:file "application-commands-extended-command")
     (:file "commands-keybinding-spec")
     (:file "command-specs-prefix-argument")))
   (:module "buffer-editing-commands"
    :pathname "../../../packages/core/buffer/src/"
    :serial t
    :components
    ((:file "application-commands-movement-view-support")
     (:file "application-commands-movement")
     (:file "application-commands-editing-support")
     (:file "application-commands-editing")
     (:file "application-commands-region")))
   (:module "minibuffer-command"
    :pathname "../../../packages/core/minibuffer/src/"
    :serial t
    :components
    ((:file "application-commands-minibuffer")))
   (:module "command-specs"
    :pathname "src/"
    :serial t
    :components
    ((:file "command-specs-input")
     (:file "command-specs-extended-command")
     (:file "command-specs-editing")
     (:file "command-specs-movement")
     (:file "command-specs-region")
     (:file "commands-keybindings")))))

(asdf:defsystem "loom-core-command/test"
  :depends-on ("loom-core-command" "loom/test-support" "cl-host-kit" "cl-tty-kit")
  :serial t
  :components
  ((:module "t"
    :serial t
    :components
    ((:module "unit"
      :serial t
      :components
      ((:file "keymap-test-support")
       (:file "keymap-lookup-test")
       (:file "keymap-state-test")
       (:file "prefix-argument-test")))
     (:module "integration"
      :serial t
      :components
      ((:file "command-registry-definition-test")
       (:file "command-spec-validation-test")
       (:file "command-help-registry-test")
       (:file "command-registration-test")
       (:file "command-keybinding-consistency-test")
       (:file "commands-keybindings-test")
       (:file "key-event-descriptor-test")
       (:file "prefix-argument-dispatch-test")
       (:file "prefix-argument-macro-test")
       (:file "prefix-argument-action-test")))))))
