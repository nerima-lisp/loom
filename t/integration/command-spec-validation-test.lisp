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
              :to-equal "LOOM/TEST-PACKAGE")
      (expect (first (third expansion)) :to-be :use)
      (expect (symbol-name (second (third expansion))) :to-equal "CL")
      (expect (first (fourth expansion)) :to-be :export)
      (expect (rest (fourth expansion)) :to-equal '("FOO" "BAR"))))

  (it "accepts a valid command-spec form and preserves help metadata"
    (let ((expansion
            (macroexpand-1
             '(loom/core/command:command-spec
               "forward-char" forward-char
               :help "Move forward"
               :help-order 10
               :mutates nil :prompts nil :needs-region nil
               :external nil :modes (:all)))))
      (expect (first expansion) :to-be 'list)
      (expect (getf (rest expansion) :name) :to-equal "forward-char")
      (expect (getf (rest expansion) :command)
              :to-equal '(quote forward-char))
      (expect (getf (rest expansion) :help) :to-equal "Move forward")
      (expect (getf (rest expansion) :help-order) :to-equal 10)))

  (it "rejects each missing required metadata field while parsing"
    (let ((metadata '(:mutates nil
                      :prompts nil
                      :needs-region nil
                      :external nil
                      :modes (:all))))
      (dolist (missing-key '(:mutates :prompts :needs-region :external :modes))
        (let ((form
                (append '(loom/core/command:command-spec
                          "forward-char" forward-char)
                        (loop for (key value) on metadata by #'cddr
                              unless (eq key missing-key)
                                append (list key value)))))
          (signals error (macroexpand-1 form))
          (signals error
            (loom/core/command::%parse-command-spec-form form))))))

  (it "rejects malformed help, external, name, and command values"
    (dolist (form
             '((loom/core/command:command-spec
                "forward-char" forward-char :help 42
                :mutates nil :prompts nil :needs-region nil :external nil :modes (:all))
               (loom/core/command:command-spec
                "forward-char" forward-char :help-order "first"
                :mutates nil :prompts nil :needs-region nil :external nil :modes (:all))
               (loom/core/command:command-spec
                "forward-char" forward-char
                :mutates nil :prompts nil :needs-region nil
                :external ("platform shell") :modes (:all))))
      (signals error (macroexpand-1 form)))
    (signals error
      (macroexpand-1
       '(loom/core/command:command-spec
         42 forward-char
         :mutates nil :prompts nil :needs-region nil :external nil :modes (:all))))
    (signals error
      (macroexpand-1
       '(loom/core/command:command-spec
         "forward-char" 42
         :mutates nil :prompts nil :needs-region nil :external nil :modes (:all)))))

  (it "rejects malformed command-spec entries and groups"
    (signals error
      (macroexpand-1
       '(loom/core/command:define-command-specs (not-a-command-spec))))
    (signals error
      (macroexpand-1
       '(loom/core/command:define-command-specs
          (loom/core/command:command-spec-group
              "movement"
            (not-a-command-spec))))
    (signals error
      (macroexpand-1 '(loom/core/command:define-command-specs 42)))
    (signals error
      (macroexpand-1
       '(loom/core/command:define-command-specs
          (loom/core/command:command-spec-group
              42
            (loom/core/command:command-spec
              "forward-char" forward-char
              :mutates nil :prompts nil :needs-region nil
              :external nil :modes (:all))))))

  (it "rejects duplicate command names case-insensitively across groups"
    (signals error
      (macroexpand-1
       '(loom/core/command:define-command-specs
          (loom/core/command:command-spec-group
              "movement"
            (loom/core/command:command-spec
              "forward-char" forward-char
              :mutates nil :prompts nil :needs-region nil :external nil :modes (:all)))
          (loom/core/command:command-spec-group
              "editing"
            (loom/core/command:command-spec
              "FORWARD-CHAR" backward-char
              :mutates nil :prompts nil :needs-region nil :external nil :modes (:all))))))
    (signals error
      (loom/core/command:build-command-specs
       '((loom/core/command:command-spec-group
             "movement"
           (loom/core/command:command-spec
             "forward-char" forward-char
             :mutates nil :prompts nil :needs-region nil :external nil :modes (:all))))
       '((loom/core/command:command-spec-group
             "editing"
           (loom/core/command:command-spec
             "FORWARD-CHAR" backward-char
             :mutates nil :prompts nil :needs-region nil :external nil :modes (:all))))))))))
