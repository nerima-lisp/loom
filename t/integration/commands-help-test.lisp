(in-package #:loom/test)

(describe
  "command completion"
  (it "filters named command IDs by a case-insensitive prefix"
    (expect
     (loom/core/command:command-completion-names "  FORWARD-C  ")
     :to-equal
     (list "forward-char")))
  (it
  "returns only registered names and excludes key-only commands"
  (let ((loom/core/command::*registered-command-specs* nil))
    (loom/core/command:register-command-spec
     :test "test/alpha" "alpha" #'identity
     :mutates nil :prompts nil :needs-region nil :external nil :modes '(:all))
    (loom/core/command:register-command-spec
     :test "test/key-only" nil #'identity
     :mutates nil :prompts nil :needs-region nil :external nil :modes '(:all))
    (loom/core/command:register-command-spec
     :test "test/beta" "Beta" #'identity
     :mutates nil :prompts nil :needs-region nil :external nil :modes '(:all))
    (expect (loom/core/command:command-completion-names "")
            :to-equal (list "alpha" "beta"))
    (expect (mapcar #'loom/core/command:command-spec-id
                    (loom/core/command:command-completion-candidates ""))
            :to-equal '("test/alpha" "test/beta"))))
  (it "finds a named command spec without exposing key-only entries"
    (let ((loom/core/command::*registered-command-specs* nil))
      (loom/core/command:register-command-spec
       :test "test/key-only" nil #'identity
       :mutates nil :prompts nil :needs-region nil :external nil :modes '(:all))
      (loom/core/command:register-command-spec
       :test "test/alpha" "Alpha" #'identity
       :mutates nil :prompts nil :needs-region nil :external nil :modes '(:all))
      (expect (loom/core/command:command-spec-id
               (loom/core/command:find-extended-command-spec "  alpha "))
              :to-equal "test/alpha")
      (expect (loom/core/command:find-extended-command-spec
               "key-only")
              :to-be nil)))
  (it "treats a missing command input as empty"
    (expect (loom/core/command:find-extended-command-spec nil)
            :to-be nil))
  (it "returns no candidates for an unknown prefix"
    (expect (loom/core/command:command-completion-names "does-not-exist")
            :to-equal nil)))

(describe
  "help summary message"
  (it "does not reorder registered command specs while sorting help entries"
    (let ((loom/core/command::*registered-command-specs* nil))
      (loom/core/command:register-command-spec
       :test "test/second" "second" #'identity
       :help "Second" :help-order 10
       :mutates nil :prompts nil :needs-region nil :external nil :modes '(:all))
      (loom/core/command:register-command-spec
       :test "test/first" "first" #'identity
       :help "First" :help-order 20
       :mutates nil :prompts nil :needs-region nil :external nil :modes '(:all))
      (let ((before (mapcar #'loom/core/command:command-spec-id
                            (loom/core/command:command-specs))))
        (expect (loom/core/command:help-summary-message)
                :to-equal "Help: Second  First")
        (expect (mapcar #'loom/core/command:command-spec-id
                        (loom/core/command:command-specs))
                :to-equal before))))
  (it "builds the help text from registry metadata"
    (expect (loom/core/command:help-summary-message)
            :to-equal
            "Help: M-x Command  M-: Eval  C-x C-e Eval buffer  M-! Pipe command  C-x g Git status  M-x git-diff  M-x git-diff-staged  M-x git-stage-file  M-x git-unstage-file  M-x format-current-buffer  M-x lsp-start  M-x lsp-stop  M-x lsp-diagnostics  C-x C-s Save  C-x C-f Open  C-x r S Save session  C-x r l Load session  C-x r f Recent file  C-x r m Set bookmark  C-x r b Jump bookmark  C-x r d Delete bookmark  C-x r s Copy region to register  C-x r i Insert register  C-x r SPC Point to register  C-x r j Jump to register  C-x ( Start macro  C-x ) End macro  C-x e Replay macro  C-s Find  C-k Cut  M-w Copy  C-y Paste  C-x C-u Undo  C-x C-y Redo  M-y Yank previous  C-x C-c Exit"))
  (it "preserves registry order for equally ordered help entries"
    (let ((loom/core/command::*registered-command-specs* nil))
      (loom/core/command:register-command-spec
       :test "test/second" "second" #'identity
       :help "Second" :help-order 10
       :mutates nil :prompts nil :needs-region nil :external nil :modes '(:all))
      (loom/core/command:register-command-spec
       :test "test/first" "first" #'identity
       :help "First" :help-order 10
       :mutates nil :prompts nil :needs-region nil :external nil :modes '(:all))
      (expect (loom/core/command:help-summary-message)
              :to-equal "Help: First  Second"))))
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
