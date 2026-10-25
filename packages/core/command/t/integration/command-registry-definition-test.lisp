(in-package #:loom/test)

(describe
  "define-command-spec-groups macroexpansion"
  (it "wraps declarative command groups in one defparameter"
    (let ((expansion
            (macroexpand-1
             '(loom/core/command:define-command-spec-groups
                  *sample-command-spec-groups*
                (loom/core/command:command-spec-group
                    "movement"
                  (loom/core/command:command-spec
                    "forward-char" forward-char
                    :mutates nil :prompts nil :needs-region nil
                    :external nil :modes (:all)))))))
      (expect expansion
              :to-equal
              '(defparameter *sample-command-spec-groups*
                 '((loom/core/command:command-spec-group
                       "movement"
                     (loom/core/command:command-spec
                       "forward-char" forward-char
                       :mutates nil :prompts nil :needs-region nil
                       :external nil :modes (:all)))))))))
(describe
  "define-command-spec-groups validation"
  (it "rejects malformed groups during macroexpansion"
    (signals error
      (macroexpand-1
       '(loom/core/command:define-command-spec-groups
         *sample-command-spec-groups*
         (loom/core/command:command-spec-group
             "movement"
           (not-a-command-spec)))))))

(describe
  "define-command-specs macroexpansion"
  (it "emits runtime data for explicit command specs"
    (let ((expansion
            (macroexpand-1
             '(loom/core/command:define-command-specs
               (loom/core/command:command-spec
                 "forward-char" forward-char
                 :mutates nil :prompts nil :needs-region nil
                 :external nil :modes (:all))
               (loom/core/command:command-spec
                 "kill-line" kill-line
                 :mutates nil :prompts nil :needs-region nil
                 :external nil :modes (:all))))))
      (expect expansion
              :to-equal
              '(list
                (list :name "forward-char"
                      :group nil
                      :command 'forward-char
                      :keys 'nil
                      :help nil
                      :help-order nil
                      :mutates nil
                      :prompts 'nil
                      :needs-region nil
                      :external 'nil
                      :modes '(:all))
                (list :name "kill-line"
                      :group nil
                      :command 'kill-line
                      :keys 'nil
                      :help nil
                      :help-order nil
                      :mutates nil
                      :prompts 'nil
                      :needs-region nil
                      :external 'nil
                      :modes '(:all)))))))

(describe
  "define-command-specs duplicate validation"
  (it "rejects command names that differ only by case"
    (signals error
      (macroexpand-1
       '(loom/core/command:define-command-specs
         (loom/core/command:command-spec
           "Forward-Char" forward-char
           :mutates nil :prompts nil :needs-region nil :external nil :modes (:all))
         (loom/core/command:command-spec
           "forward-char" backward-char
           :mutates nil :prompts nil :needs-region nil :external nil :modes (:all)))))))

(describe
  "define-command-spec-catalog"
  (it "composes spec blocks through the command builder"
    (expect
     (macroexpand-1
      '(loom/core/command:define-command-spec-catalog
        movement-specs editing-specs))
     :to-equal
     '(loom/core/command:build-command-specs movement-specs editing-specs)))
  (it "preserves groups and metadata when building specs"
    (expect
     (loom/core/command:build-command-specs
      '((loom/core/command:command-spec-group
          "movement"
        (loom/core/command:command-spec
          "forward-char" forward-char
          :keys ((:control #\f))
          :help "C-f Forward"
          :help-order 10
          :mutates t :prompts (:free-string) :needs-region t
          :external ("rg") :modes (:common-lisp)))
        (loom/core/command:command-spec-group
          "editing"
        (loom/core/command:command-spec
          "kill-line" kill-line
          :keys nil
          :help nil :help-order nil
          :mutates nil :prompts nil :needs-region nil
          :external nil :modes (:all)))))
     :to-equal
     '((:name "forward-char" :group "movement"
        :command forward-char :keys ((:control #\f))
        :help "C-f Forward" :help-order 10
        :mutates t :prompts (:free-string) :needs-region t
        :external ("rg") :modes (:common-lisp))
       (:name "kill-line" :group "editing"
        :command kill-line :keys nil :help nil :help-order nil
        :mutates nil :prompts nil :needs-region nil
        :external nil :modes (:all))))))
