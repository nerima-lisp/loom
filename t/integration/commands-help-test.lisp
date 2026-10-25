(in-package #:loom/test)

(describe "help command"
  (it "shows the primary command reference in the minibuffer"
    (%with-minibuffer-state (minibuffer "")
      (loom::help-command)
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal
              (loom/core/command:help-summary-message))))
  (it-each
      (("C-h" (((:control) . #\h)) "help")
       ("F1" ((nil . :f1)) "help"))
      "binds ~A to the stable help command ID" (label key-sequence command-id)
    (declare (ignore label))
    (let ((keymap (make-keymap)))
      (loom/core/command:install-default-keybindings keymap)
      (expect (keymap-lookup keymap key-sequence)
              :to-equal command-id))))
