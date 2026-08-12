(in-package #:loom/test)

(describe
  "command completion"
  (it "filters candidates by a case-insensitive prefix"
    (expect
     (loom/application:command-completion-candidates "  FORWARD-C  ")
     :to-equal
     (list "forward-char")))
  (it "returns all named commands for an empty prefix"
    (let ((expected
            (loop for spec in loom/application:*command-specs*
                  for name = (getf spec :name)
                  when name collect name)))
      (expect (loom/application:command-completion-candidates "")
              :to-equal
              expected)))
  (it "returns no candidates for an unknown prefix"
    (expect
     (loom/application:command-completion-candidates "does-not-exist")
     :to-equal
     nil)))

(describe "help summary message"
  (it "builds the help text from registry metadata"
    (expect (loom/application:help-summary-message)
            :to-equal
            "Help: M-x Command  M-: Eval  C-x C-e Eval buffer  M-! Pipe command  C-x g Git status  M-x git-diff  M-x git-diff-staged  M-x git-stage-file  M-x git-unstage-file  M-x format-current-buffer  M-x lsp-start  M-x lsp-stop  M-x lsp-diagnostics  C-x C-s Save  C-x C-f Open  C-x r S Save session  C-x r l Load session  C-x r f Recent file  C-x r m Set bookmark  C-x r b Jump bookmark  C-x r d Delete bookmark  C-x r s Copy region to register  C-x r i Insert register  C-x r SPC Point to register  C-x r j Jump to register  C-x ( Start macro  C-x ) End macro  C-x e Replay macro  C-s Find  C-k Cut  M-w Copy  C-y Paste  C-x C-u Undo  C-x C-y Redo  M-y Yank previous  C-x C-c Exit")))

(describe "help command"
  (it "shows the primary command reference in the minibuffer"
    (%with-minibuffer-state (minibuffer "")
      (loom::help-command)
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal
              (loom/application:help-summary-message))))
  (it-each
      (("C-h" (((:control) . #\h)) loom::help-command)
       ("F1" ((nil . :f1)) loom::help-command))
      "binds ~A to help-command" (label key-sequence command)
    (declare (ignore label))
    (let ((keymap (make-keymap)))
      (loom/application:install-default-keybindings keymap)
      (expect (keymap-lookup keymap key-sequence) :to-be command))))
