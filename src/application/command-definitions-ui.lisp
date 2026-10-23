(in-package #:loom)

(define-command-spec-groups *ui-command-spec-groups*
  (command-spec-group "ui and lifecycle"
      (command-spec "keyboard-quit" keyboard-quit :keys ((:control #\g))
                    :mutates nil
                    :prompts nil
                    :needs-region nil
                    :external nil
                    :modes (:all))
      (command-spec "help" help-command :keys ((:control #\h) :f1)
                    :mutates nil
                    :prompts nil
                    :needs-region nil
                    :external nil
                    :modes (:all))
      (command-spec "save-buffers-kill-terminal" save-buffers-kill-terminal
                    :keys (((:control #\x) (:control #\c)))
                    :help "C-x C-c Exit"
                    :help-order 37
                    :mutates nil
                    :prompts (:free-string)
                    :needs-region nil
                    :external nil
                    :modes (:all))
      (command-spec nil execute-extended-command
                    :keys ((:alt #\x))
                    :help "M-x Command"
                    :help-order 1
                    :mutates nil
                    :prompts (:completion)
                    :needs-region nil
                    :external nil
                    :modes (:all))))
