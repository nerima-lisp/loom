(in-package #:loom/test)

(describe "core package bootstrap"
  (it "loads the root and feature packages"
    (expect (find-package "LOOM") :to-be-truthy)
    (expect (find-package "LOOM/CORE/COMMAND") :to-be-truthy)
    (expect (find-package "LOOM/FEATURE/FILES") :to-be-truthy)
    (expect (find-package "LOOM/FEATURE/BOOKMARK") :to-be-truthy))
  (it "exports cross-slice command symbols"
    (expect (every (lambda (name)
                     (eq (nth-value 1 (find-symbol name "LOOM"))
                         :external))
                   '("DELETE-CHAR"
                     "DELETE-BACKWARD-CHAR"
                     "NEWLINE-COMMAND"
                     "OPEN-LINE"
                     "FORWARD-CHAR"
                     "BACKWARD-CHAR"
                     "NEXT-LINE"
                     "PREVIOUS-LINE"
                     "FORWARD-WORD"
                     "BACKWARD-WORD"
                     "MOVE-BEGINNING-OF-LINE"
                     "MOVE-END-OF-LINE"
                     "BEGINNING-OF-BUFFER"
                     "END-OF-BUFFER"
                     "GOTO-LINE"
                     "SET-MARK-COMMAND"
                     "EXCHANGE-POINT-AND-MARK"
                     "MARK-WHOLE-BUFFER"
                     "NARROW-TO-REGION"
                     "WIDEN"
                     "TOGGLE-READ-ONLY"
                     "UNDO-COMMAND"
                     "REDO-COMMAND"
                     "KEYBOARD-QUIT"
                     "KILL-LINE"
                     "KILL-WORD"
                     "BACKWARD-KILL-WORD"
                     "KILL-REGION"
                     "KILL-RING-SAVE"
                     "FORWARD-SLURP-SEXP"
                     "FORWARD-BARF-SEXP"
                     "BACKWARD-SLURP-SEXP"
                     "BACKWARD-BARF-SEXP"
                     "WRAP-ROUND"
                     "SPLICE-SEXP"
                     "RAISE-SEXP"))
            :to-be-truthy)))
