(in-package #:loom/test)

(describe
  "command completion"
  (it "filters candidates by a case-insensitive prefix"
    (expect
     (loom/application:command-completion-candidates "  FORWARD-C  ")
     :to-equal
     (list "forward-char")))
  (it "returns all named commands for an empty prefix"
    (let ((loom/application:*command-specs*
            (list (list :name "alpha" :command 'alpha-command :keys nil)
                  (list :name nil :command 'keymap-only-command :keys nil)
                  (list :name "Beta" :command 'beta-command :keys nil))))
      (expect (loom/application:command-completion-candidates "")
              :to-equal
              (list "alpha" "Beta"))))
  (it "finds a named command without exposing keymap-only entries"
    (let ((loom/application:*command-specs*
            (list (list :name nil :command 'keymap-only-command :keys nil)
                  (list :name "Alpha" :command 'alpha-command :keys nil))))
      (expect (loom/application:find-extended-command "  alpha ")
              :to-be
              'alpha-command)
      (expect (loom/application:find-extended-command "keymap-only-command")
              :to-be
              nil)))
  (it "treats a missing command input as empty"
    (expect (loom/application:find-extended-command nil)
            :to-be
            nil))
  (it "returns no candidates for an unknown prefix"
    (expect
     (loom/application:command-completion-candidates "does-not-exist")
     :to-equal
     nil)))

(describe "help summary message"
  (it "does not reorder the command registry while sorting help entries"
    (let* ((first (list :name "first" :help "First" :help-order 20))
           (second (list :name "second" :help "Second" :help-order 10))
           (loom/application:*command-specs* (list first second)))
      (expect (loom/application:help-summary-message)
              :to-equal
              "Help: Second  First")
      (expect loom/application:*command-specs*
              :to-equal
              (list first second))))
  (it "builds the help text from registry metadata"
    (expect (loom/application:help-summary-message)
              :to-equal
              "Help: M-x Command  M-: Eval  C-x C-e Eval buffer  M-! Pipe command  C-x g Git status  M-x git-diff  M-x git-diff-staged  M-x git-stage-file  M-x git-unstage-file  M-x format-current-buffer  M-x lsp-start  M-x lsp-stop  M-x lsp-diagnostics  C-x C-s Save  C-x C-f Open  C-x r S Save session  C-x r l Load session  C-x r f Recent file  C-x r m Set bookmark  C-x r b Jump bookmark  C-x r d Delete bookmark  C-x r s Copy region to register  C-x r i Insert register  C-x r SPC Point to register  C-x r j Jump to register  C-x ( Start macro  C-x ) End macro  C-x e Replay macro  C-s Find  C-k Cut  M-w Copy  C-y Paste  C-x C-u Undo  C-x C-y Redo  M-y Yank previous  C-x C-c Exit")))
  (it "preserves registration order for equally ordered help entries"
    (let* ((first (list :name "first" :help "First" :help-order 10))
           (second (list :name "second" :help "Second" :help-order 10))
           (loom/application:*command-specs* (list first second)))
      (expect (loom/application:help-summary-message)
              :to-equal
              "Help: First  Second")))

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
