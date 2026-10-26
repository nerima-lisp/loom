(asdf:defsystem "loom-feature-terminal"
  :depends-on ("loom-core-buffer"
               "loom-core-editor-session"
               "loom-core-minibuffer"
               "loom-core-window-tree"
               "loom-core-command"
               "loom-feature-buffers"
               "cl-tty-kit")
  :serial t
  :components
  ((:module "src"
    :serial t
    :components
    ((:file "package")
     (:file "domain-terminal-support")
     (:file "domain-terminal")
     (:file "domain-terminal-screen-operations")
     (:file "domain-terminal-screen-state")
     (:file "domain-terminal-csi-screen-operations")
     (:file "domain-terminal-csi-cursor")
     (:file "domain-terminal-csi-edit")
     (:file "domain-terminal-parser-csi")
     (:file "domain-terminal-parser")
     (:file "domain-terminal-session")
     (:file "infrastructure-terminal")
     (:file "infrastructure-terminal-session-runtime")
     (:file "infrastructure-terminal-event-loop")
     (:file "application-terminal-input-support")
     (:file "application-terminal-input")
     (:file "application-terminal-event-loop")
     (:file "application-terminal-hooks")
     (:file "application-commands-terminal")
     (:file "command-specs-terminal")))))

(asdf:defsystem "loom-feature-terminal/test"
  :depends-on ("loom-feature-terminal"
               "loom/test-support"
               "cl-weave"
               "cl-tty-kit")
  :serial t
  :components
  ((:file "t/unit/terminal-event-test")
   (:file "t/unit/terminal-screen-basic-test")
   (:file "t/unit/terminal-screen-control-test")
   (:file "t/unit/terminal-screen-cursor-test")
   (:file "t/unit/terminal-screen-validation-test")
   (:file "t/unit/terminal-session-lifecycle-test")
   (:file "t/unit/terminal-session-test")))
