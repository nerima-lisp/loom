(in-package #:loom/test)

(describe "command registration"
  (it-each
      (("pipe-command"
        loom/feature/shell:pipe-command
        (((:alt) . #\!)))
       ("format-current-buffer"
        loom/feature/format:format-current-buffer
        nil)
       ("git-status"
        loom/feature/git:git-status
        (((:control) . #\x) (nil . #\g)))
       ("git-diff"
        loom/feature/git:git-diff
        nil)
       ("git-diff-staged"
        loom/feature/git:git-diff-staged
        nil)
       ("git-stage-file"
        loom/feature/git:git-stage-file
        nil)
       ("git-unstage-file"
        loom/feature/git:git-unstage-file
        nil))
      "registers ~A in the command catalogue" (name command key-sequence)
    (expect (loom/application:find-extended-command name)
            :to-be
            command)
    (when key-sequence
      (let ((keymap (make-keymap)))
        (loom/application:install-default-keybindings keymap)
        (expect (keymap-lookup keymap key-sequence) :to-be command)))))

(describe "execute-extended-command"
  (it "resolves a registered command through the command-spec registry"
    (%with-minibuffer-state (minibuffer "hi")
      (loom::execute-extended-command)
      (%expect-minibuffer-prompt minibuffer (%m-x-prompt-string))
      (funcall (loom::%minibuffer-on-confirm minibuffer) "  FORWARD-CHAR  ")
      (expect (buffer-point-column (%selected-test-buffer)) :to-equal 1)))
  (it "completes a registered command with Tab"
    (%with-minibuffer-state (minibuffer "hi")
      (loom::execute-extended-command)
      (%type-string minibuffer "forward-c")
      (minibuffer-handle-key minibuffer (%special-key :tab))
      (expect (minibuffer-input-string minibuffer) :to-equal "forward-char")
      (minibuffer-handle-key minibuffer (%special-key :enter))
      (expect (buffer-point-column (%selected-test-buffer)) :to-equal 1)))
  (it "reports an unregistered command without evaluating it"
    (%with-minibuffer-state (minibuffer "hi")
      (loom::execute-extended-command)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "not-a-command")
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal "Unknown command: not-a-command")))
  (it "binds M-x to execute-extended-command"
    (let ((keymap (make-keymap)))
      (loom/application:install-default-keybindings keymap)
      (expect (keymap-lookup keymap (list (cons (quote (:alt)) #\x)))
              :to-be (quote loom::execute-extended-command)))))
