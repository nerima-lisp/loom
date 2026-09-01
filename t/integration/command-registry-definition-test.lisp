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
             (quote
               (loom/application:define-command-specs
                 (loom/application:command-spec "forward-char" forward-char)
                 (loom/application:command-spec "kill-line" kill-line))))))
      (expect (first expansion) :to-equal (quote defparameter))
      (expect (second expansion)
              :to-equal
              (quote loom/application:*command-specs*))
      (expect (third expansion)
              :to-equal
              (quote
                (list
                  (list :name "forward-char"
                        :command (quote forward-char)
                        :keys (quote nil)
                        :help nil
                        :help-order nil)
                  (list :name "kill-line"
                        :command (quote kill-line)
                        :keys (quote nil)
                        :help nil
                        :help-order nil))))
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
  (it "builds the explicit command registry from grouped spec variables"
    (let ((loom::*command-specs* nil)
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
            movement-specs
            editing-specs)))
      (expect loom/application:*command-specs*
              :to-equal
              '((:name "forward-char"
                 :command forward-char
                 :keys nil
                 :help nil
                 :help-order nil)
                (:name "kill-line"
                 :command kill-line
                 :keys nil
                 :help nil
                 :help-order nil)))))
  (it "preserves command metadata while composing grouped spec variables"
    (let ((loom/application:*command-specs* nil)
          (movement-specs
            '((loom/application:command-spec-group
                  "movement"
                (loom/application:command-spec
                    "forward-char" forward-char
                  :keys (((:control #\f)))
                  :help "C-f Forward"
                  :help-order 10)))))
      (eval
       `(let ((movement-specs ',movement-specs))
          (loom/application:define-command-spec-catalog movement-specs)))
      (expect loom/application:*command-specs*
              :to-equal
              '((:name "forward-char"
                 :command forward-char
                 :keys (((:control #\f)))
                 :help "C-f Forward"
                 :help-order 10))))))
