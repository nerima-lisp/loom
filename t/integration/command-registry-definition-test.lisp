(in-package #:loom/test)

(describe
  "define-command-spec-groups macroexpansion"
  (it "wraps declarative command groups in one defparameter"
    (let ((expansion
            (macroexpand-1
             (quote
               (loom/application:define-command-spec-groups
                   *sample-command-spec-groups*
                 (loom/application:command-spec-group
                     "movement"
                   (loom/application:command-spec
                       "forward-char"
                     forward-char)))))))
      (expect expansion
              :to-equal
              '(defparameter *sample-command-spec-groups*
                 '((loom/application:command-spec-group
                       "movement"
                     (loom/application:command-spec
                       "forward-char"
                       forward-char))))))))
(describe
  "define-command-spec-groups validation"
  (it "rejects malformed groups during macroexpansion"
    (signals error
      (macroexpand-1
       '(loom/application:define-command-spec-groups
         *sample-command-spec-groups*
         (loom/application:command-spec-group
             "movement"
           (not-a-command-spec)))))))

(describe
  "define-command-specs macroexpansion"
  (it "emits only the explicit command registry"
    (let ((expansion
            (macroexpand-1
             '(loom/application:define-command-specs
               (loom/application:command-spec "forward-char" forward-char)
               (loom/application:command-spec "kill-line" kill-line)))))
      (expect (first expansion) :to-equal 'defparameter)
      (expect (second expansion)
              :to-equal 'loom/application:*command-specs*)
      (expect (third expansion)
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
                      :modes '(:all))))
      (expect (fourth expansion) :to-be nil))))

(describe
  "define-command-specs duplicate validation"
  (it "rejects command names that differ only by case"
    (signals error
      (macroexpand-1
       '(loom/application:define-command-specs
         (loom/application:command-spec "Forward-Char" forward-char)
         (loom/application:command-spec "forward-char" backward-char))))))

(describe
  "define-command-spec-catalog"
  (it "preserves groups and default metadata when composing spec variables"
    (let ((loom/application:*command-specs* nil)
          (movement-specs
            '((loom/application:command-spec-group
                "movement"
                (loom/application:command-spec "forward-char" forward-char))))
          (editing-specs
            '((loom/application:command-spec-group
                "editing"
                (loom/application:command-spec "kill-line" kill-line)))))
      (eval
       `(let ((movement-specs ',movement-specs)
              (editing-specs ',editing-specs))
          (loom/application:define-command-spec-catalog
            movement-specs editing-specs)))
      (expect loom/application:*command-specs*
              :to-equal
              '((:name "forward-char" :group "movement"
                 :command forward-char :keys nil :help nil :help-order nil
                 :mutates nil :prompts nil :needs-region nil :external nil
                 :modes (:all))
                (:name "kill-line" :group "editing"
                 :command kill-line :keys nil :help nil :help-order nil
                 :mutates nil :prompts nil :needs-region nil :external nil
                 :modes (:all))))))
  (it "preserves explicit metadata in grouped command specs"
    (let ((specs
            (loom/application:build-command-specs
             '((loom/application:command-spec-group
                 "movement"
                 (loom/application:command-spec
                   "forward-char" forward-char
                   :keys ((:control #\f))
                   :help "C-f Forward"
                   :help-order 10
                   :mutates t
                   :prompts (:free-string)
                   :needs-region t
                   :external ("rg")
                   :modes (:common-lisp)))))))
      (expect specs
              :to-equal
              '((:name "forward-char" :group "movement"
                 :command forward-char :keys ((:control #\f))
                 :help "C-f Forward" :help-order 10
                 :mutates t :prompts (:free-string) :needs-region t
                 :external ("rg") :modes (:common-lisp)))))))
