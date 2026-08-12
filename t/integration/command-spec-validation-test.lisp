(in-package #:loom/test)

(describe
  "command-spec validation"
  (it "accepts a valid command-spec command"
    (let ((expansion
            (macroexpand-1
             '(loom/application:command-spec "forward-char" forward-char))))
      (expect (first expansion) :to-be 'list)
      (expect (getf (rest expansion) :name) :to-equal "forward-char")
      (expect (getf (rest expansion) :command)
              :to-equal
              (quote (quote forward-char)))
      (expect (getf (rest expansion) :help) :to-be nil)
      (expect (getf (rest expansion) :help-order) :to-be nil)))
  (it "rejects a non-string command-spec name"
    (signals error
      (macroexpand-1 '(loom/application:command-spec 42 forward-char))))
  (it "rejects a non-symbol command-spec command"
    (signals error
      (macroexpand-1 '(loom/application:command-spec "forward-char" 42))))
  (it "rejects a non-command-spec registry entry"
    (signals error
      (macroexpand-1 '(loom/application:define-command-specs (not-a-command-spec)))))
  (it "rejects a non-command-spec group entry"
    (signals error
      (macroexpand-1
       '(loom/application:define-command-specs
          (loom/application:command-spec-group
              "movement"
            (not-a-command-spec))))))
  (it "rejects an atom registry entry"
    (signals error
      (macroexpand-1 '(loom/application:define-command-specs 42))))
  (it "rejects a non-string registry name"
    (signals error
      (macroexpand-1
       '(loom/application:define-command-specs
          (loom/application:command-spec 42 forward-char)))))
  (it "rejects a non-symbol registry command"
    (signals error
      (macroexpand-1
       '(loom/application:define-command-specs
          (loom/application:command-spec "forward-char" 42)))))
  (it "rejects duplicate registry names case-insensitively"
    (signals error
      (macroexpand-1
       '(loom/application:define-command-specs
          (loom/application:command-spec "forward-char" forward-char)
          (loom/application:command-spec-group
              "movement"
            (loom/application:command-spec "kill-line" kill-line))
          (loom/application:command-spec-group
              "editing"
            (loom/application:command-spec "FORWARD-CHAR" backward-char))))))
  (it "rejects duplicate names across grouped spec variables"
    (signals error
      (loom/application:build-command-specs
       '((loom/application:command-spec-group
             "movement"
           (loom/application:command-spec "forward-char" forward-char)))
       '((loom/application:command-spec-group
             "editing"
           (loom/application:command-spec "FORWARD-CHAR" backward-char))))))
  (it "flattens grouped command specs into the explicit registry"
    (let ((expansion
            (macroexpand-1
             '(loom/application:define-command-specs
                (loom/application:command-spec-group
                    "movement"
                  (loom/application:command-spec "forward-char" forward-char)
                  (loom/application:command-spec "kill-line" kill-line))))))
      (expect (third (second expansion))
              :to-equal
              '(list
                (list :name "forward-char"
                      :command (quote forward-char)
                      :keys (quote nil)
                      :help nil
                      :help-order nil)
                (list :name "kill-line"
                      :command (quote kill-line)
                      :keys (quote nil)
                      :help nil
                      :help-order nil))))))
