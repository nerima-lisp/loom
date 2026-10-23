(in-package #:loom/test)

(describe
  "command-spec validation"
  (it "expands the package export definition into a defpackage form"
    (let ((expansion
            (macroexpand-1
             '(cl-user::define-package-with-exports
                #:loom/test-package (#:cl) (foo bar)))))
      (expect (first expansion) :to-be 'defpackage)
      (expect (symbol-name (second expansion))
              :to-equal
              "LOOM/TEST-PACKAGE")
      (expect (first (third expansion)) :to-be :use)
      (expect (symbol-name (second (third expansion))) :to-equal "CL")
      (expect (first (fourth expansion)) :to-be :export)
      (expect (rest (fourth expansion)) :to-equal '("FOO" "BAR"))))
  (it "accepts a valid command-spec command"
    (let ((expansion
            (macroexpand-1
             '(loom/application:command-spec
               "forward-char" forward-char
               :mutates nil :prompts nil :needs-region nil
               :external nil :modes (:all)))))
      (expect (first expansion) :to-be 'list)
      (expect (getf (rest expansion) :name) :to-equal "forward-char")
      (expect (getf (rest expansion) :command)
              :to-equal
              (quote (quote forward-char)))
      (expect (getf (rest expansion) :help) :to-be nil)
      (expect (getf (rest expansion) :help-order) :to-be nil)))
  (it "preserves valid help metadata"
    (let ((expansion
            (macroexpand-1
             '(loom/application:command-spec
               "forward-char" forward-char
               :help "Move forward"
               :help-order 10
               :mutates nil :prompts nil :needs-region nil
               :external nil :modes (:all)))))
      (expect (getf (rest expansion) :help) :to-equal "Move forward")
      (expect (getf (rest expansion) :help-order) :to-equal 10)))
  (it "rejects malformed and missing command metadata"
    (dolist (form
             '((loom/application:command-spec
                "forward-char" forward-char :help 42)
               (loom/application:command-spec
                "forward-char" forward-char :help-order "first")))
      (signals error (macroexpand-1 form)))
    (let ((metadata '(:mutates nil
                      :prompts nil
                      :needs-region nil
                      :external nil
                      :modes (:all))))
      (dolist (missing-key '(:mutates :prompts :needs-region :external :modes))
        (let ((form
                (append '(loom/application:command-spec
                          "forward-char" forward-char)
                        (loop for (key value) on metadata by #'cddr
                              unless (eq key missing-key)
                                append (list key value)))))
          (signals error (macroexpand-1 form))
          (signals error
            (loom/application::%parse-command-spec-form form)))))
    (signals error
      (loom/application::%parse-command-spec-form
       '(loom/application:command-spec
         "forward-char" forward-char
         :mutates nil :prompts nil :needs-region nil
         :external ("platform shell") :modes (:all)))))
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
          (loom/application:command-spec 42 forward-char :mutates nil :prompts nil :needs-region nil :external nil :modes (:all))))))
  (it "rejects a non-symbol registry command"
    (signals error
      (macroexpand-1
       '(loom/application:define-command-specs
          (loom/application:command-spec "forward-char" 42 :mutates nil :prompts nil :needs-region nil :external nil :modes (:all))))))
  (it "rejects duplicate registry names case-insensitively"
    (signals error
      (macroexpand-1
       '(loom/application:define-command-specs
          (loom/application:command-spec "forward-char" forward-char :mutates nil :prompts nil :needs-region nil :external nil :modes (:all))
          (loom/application:command-spec-group
              "movement"
            (loom/application:command-spec "kill-line" kill-line :mutates nil :prompts nil :needs-region nil :external nil :modes (:all)))
          (loom/application:command-spec-group
              "editing"
            (loom/application:command-spec "FORWARD-CHAR" backward-char :mutates nil :prompts nil :needs-region nil :external nil :modes (:all)))))))
  (it "rejects duplicate names across grouped spec variables"
    (signals error
      (loom/application:build-command-specs
       '((loom/application:command-spec-group
             "movement"
           (loom/application:command-spec "forward-char" forward-char :mutates nil :prompts nil :needs-region nil :external nil :modes (:all))))
       '((loom/application:command-spec-group
             "editing"
           (loom/application:command-spec "FORWARD-CHAR" backward-char :mutates nil :prompts nil :needs-region nil :external nil :modes (:all)))))))
  (it "flattens grouped command specs into the explicit registry"
    (let ((expansion
            (macroexpand-1
             '(loom/application:define-command-specs
                (loom/application:command-spec-group
                    "movement"
                  (loom/application:command-spec "forward-char" forward-char :mutates nil :prompts nil :needs-region nil :external nil :modes (:all))
                  (loom/application:command-spec "kill-line" kill-line :mutates nil :prompts nil :needs-region nil :external nil :modes (:all)))))))
      (expect (third expansion)
              :to-equal
              (quote
                (list
                  (list :name "forward-char"
                        :group "movement"
                        :command (quote forward-char)
                        :keys (quote nil)
                        :help nil
                        :help-order nil
                        :mutates nil
                        :prompts (quote nil)
                        :needs-region nil
                        :external (quote nil)
                        :modes (quote (:all)))
                  (list :name "kill-line"
                        :group "movement"
                        :command (quote kill-line)
                        :keys (quote nil)
                        :help nil
                        :help-order nil
                        :mutates nil
                        :prompts (quote nil)
                        :needs-region nil
                        :external (quote nil)
                        :modes (quote (:all)))))))))
