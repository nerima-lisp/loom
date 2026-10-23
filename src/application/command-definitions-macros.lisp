(in-package #:loom)

(define-command-spec-groups *macros-command-spec-groups*
  (command-spec-group "macros and evaluation"
      (command-spec "start-kbd-macro" loom/feature/keyboard-macro:start-kbd-macro
                    :keys (((:control #\x) #\())
                    :help "C-x ( Start macro"
                    :help-order 27
                    :mutates nil
                    :prompts nil
                    :needs-region nil
                    :external nil
                    :modes (:all))
      (command-spec "end-kbd-macro" loom/feature/keyboard-macro:end-kbd-macro
                    :keys (((:control #\x) #\)))
                    :help "C-x ) End macro"
                    :help-order 28
                    :mutates nil
                    :prompts nil
                    :needs-region nil
                    :external nil
                    :modes (:all))
      (command-spec "call-last-kbd-macro"
                    loom/feature/keyboard-macro:call-last-kbd-macro
                    :keys (((:control #\x) #\e))
                    :help "C-x e Replay macro"
                    :help-order 29
                    :mutates t
                    :prompts nil
                    :needs-region nil
                    :external nil
                    :modes (:all))
      (command-spec "eval-expression" loom/feature/evaluation:eval-expression
                    :keys ((:alt #\:))
                    :help "M-: Eval"
                    :help-order 2
                    :mutates t
                    :prompts (:free-string)
                    :needs-region nil
                    :external nil
                    :modes (:all))
      (command-spec "eval-buffer" loom/feature/evaluation:eval-buffer
                    :keys (((:control #\x) (:control #\e)))
                    :help "C-x C-e Eval buffer"
                    :help-order 3
                    :mutates t
                    :prompts nil
                    :needs-region nil
                    :external nil
                    :modes (:all))))
