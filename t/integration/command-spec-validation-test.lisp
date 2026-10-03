(in-package #:loom/test)

(defun %package-export-snapshot (package-name)
  "Return a stable snapshot key for PACKAGE-NAME's external symbols."
  (let ((hash 2166136261))
    (labels ((mix (string)
               (loop for character across string
                     do (setf hash
                              (logand #xffffffff
                                      (* (logxor hash (char-code character))
                                         16777619))))))
      (mix package-name)
      (dolist (name (sort (loop for symbol being the external-symbols
                                of (find-package package-name)
                                collect (symbol-name symbol))
                          #'string<))
        (mix " ")
        (mix name)))
    hash))

(defparameter +package-export-snapshots+
  '(("LOOM" . #x2B4304D4)
    ("LOOM/APPLICATION" . #xFABFDEB5)
    ("LOOM-USER" . #x14B89E80)
    ("LOOM/FEATURE/AUTO-SAVE" . #xA3B35463)
    ("LOOM/FEATURE/EVALUATION" . #x147099EC)
    ("LOOM/FEATURE/FILE-TREE" . #x796F55CE)
    ("LOOM/FEATURE/FORMAT" . #x1B81B618)
    ("LOOM/FEATURE/GIT" . #x85B4C1D1)
    ("LOOM/FEATURE/KEYBOARD-MACRO" . #x6258058D)
    ("LOOM/FEATURE/LSP" . #xAC241E03)
    ("LOOM/FEATURE/MODE" . #xA68FB22C)
    ("LOOM/FEATURE/PROJECT" . #x6985A7BD)
    ("LOOM/FEATURE/REGISTER" . #x63EE2BAF)
    ("LOOM/FEATURE/SEARCH" . #x92328356)
    ("LOOM/FEATURE/SESSION" . #x8A2B4F71)
    ("LOOM/FEATURE/SHELL" . #xFD8E0C33)
    ("LOOM/FEATURE/SYNTAX-HIGHLIGHTING" . #xB9B2D62E)
    ("LOOM/FEATURE/TERMINAL" . #x057201CD)
    ("LOOM/FEATURE/USER-INIT" . #x19687ACF)
    ("LOOM/FEATURE/WINDOW" . #xE26B6FB5)
    ("LOOM/FEATURE/WORKSPACE" . #x961E188B)))

(defparameter +package-use-snapshots+
  '(("LOOM" "COMMON-LISP" "LOOM/APPLICATION")
    ("LOOM/APPLICATION" "COMMON-LISP")
    ("LOOM-USER" "COMMON-LISP" "LOOM" "LOOM/FEATURE/LSP" "LOOM/FEATURE/MODE"
     "LOOM/FEATURE/USER-INIT")
    ("LOOM/FEATURE/AUTO-SAVE" "COMMON-LISP" "LOOM" "LOOM/APPLICATION")
    ("LOOM/FEATURE/EVALUATION" "COMMON-LISP" "LOOM" "LOOM/APPLICATION"
     "LOOM/FEATURE/WINDOW")
    ("LOOM/FEATURE/FILE-TREE" "COMMON-LISP" "LOOM" "LOOM/APPLICATION"
     "LOOM/FEATURE/WINDOW")
    ("LOOM/FEATURE/FORMAT" "COMMON-LISP" "LOOM" "LOOM/APPLICATION"
     "LOOM/FEATURE/SHELL")
    ("LOOM/FEATURE/GIT" "COMMON-LISP" "LOOM" "LOOM/APPLICATION" "LOOM/FEATURE/PROJECT"
     "LOOM/FEATURE/WINDOW" "VCS-KIT")
    ("LOOM/FEATURE/KEYBOARD-MACRO" "COMMON-LISP" "LOOM" "LOOM/APPLICATION")
    ("LOOM/FEATURE/LSP" "COMMON-LISP" "LOOM" "LOOM/APPLICATION")
    ("LOOM/FEATURE/MODE" "COMMON-LISP" "LOOM" "LOOM/APPLICATION")
    ("LOOM/FEATURE/PROJECT" "COMMON-LISP" "LOOM" "LOOM/APPLICATION")
    ("LOOM/FEATURE/REGISTER" "COMMON-LISP" "LOOM" "LOOM/APPLICATION")
    ("LOOM/FEATURE/SEARCH" "COMMON-LISP" "LOOM" "LOOM/APPLICATION")
    ("LOOM/FEATURE/SESSION" "COMMON-LISP" "LOOM" "LOOM/APPLICATION"
     "LOOM/FEATURE/WINDOW")
    ("LOOM/FEATURE/SHELL" "COMMON-LISP" "LOOM" "LOOM/APPLICATION"
     "LOOM/FEATURE/WINDOW")
    ("LOOM/FEATURE/SYNTAX-HIGHLIGHTING" "COMMON-LISP" "LOOM" "LOOM/FEATURE/MODE")
    ("LOOM/FEATURE/TERMINAL" "COMMON-LISP" "LOOM" "LOOM/APPLICATION"
     "LOOM/FEATURE/WINDOW")
    ("LOOM/FEATURE/USER-INIT" "COMMON-LISP" "LOOM" "LOOM/APPLICATION")
    ("LOOM/FEATURE/WINDOW" "COMMON-LISP" "LOOM" "LOOM/APPLICATION")
    ("LOOM/FEATURE/WORKSPACE" "COMMON-LISP" "LOOM" "LOOM/APPLICATION"
     "LOOM/FEATURE/WINDOW")))

(defun %package-use-names (package-name)
  (sort (mapcar #'package-name (package-use-list (find-package package-name)))
        #'string<))

(describe
  "package boundary contracts"
  (it "matches the checked-in external symbol snapshots"
    (dolist (snapshot +package-export-snapshots+)
      (expect (%package-export-snapshot (car snapshot))
              :to-equal
              (cdr snapshot))))
  (it "matches the allowed package dependency directions"
    (dolist (snapshot +package-use-snapshots+)
      (expect
       (equal (%package-use-names (first snapshot))
              (sort (copy-list (rest snapshot)) #'string<))
       :to-be
       t))))

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
             '(loom/application:command-spec "forward-char" forward-char))))
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
               :help-order 10))))
      (expect (getf (rest expansion) :help) :to-equal "Move forward")
      (expect (getf (rest expansion) :help-order) :to-equal 10)))
  (it "preserves valid key metadata"
    (let ((expansion
            (macroexpand-1
             '(loom/application:command-spec
               "forward-char" forward-char
               :keys (((:control #\f)))))))
      (expect (getf (rest expansion) :keys)
              :to-equal
              '(quote (((:control #\f)))))))
  (it "rejects invalid optional command metadata"
    (dolist (form
              '((loom/application:command-spec
                 "forward-char" forward-char :help 42)
                (loom/application:command-spec
                 "forward-char" forward-char :help-order "first")))
      (signals error (macroexpand-1 form))))
  (it "rejects unknown or incomplete command options"
    (dolist (form
              '((loom/application:command-spec
                 "forward-char" forward-char :unknown t)
                (loom/application:command-spec
                 "forward-char" forward-char :help)))
      (signals error (macroexpand-1 form))))
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
  (it "rejects empty command groups"
    (signals error
      (macroexpand-1
       '(loom/application:define-command-specs
          (loom/application:command-spec-group "movement")))))
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
      (expect (third expansion)
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
