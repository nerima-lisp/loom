;;;; src/application/command-definitions-ui.lisp
;;;;
;;;; Declarative command catalogue for UI and lifecycle commands.
(in-package #:loom)

(define-command-spec-groups *ui-command-spec-groups*
  (command-spec-group "ui and lifecycle"
      (command-spec "keyboard-quit" keyboard-quit :keys ((:control #\g)))
      (command-spec "help" help-command :keys ((:control #\h) :f1))
      (command-spec "save-buffers-kill-terminal" save-buffers-kill-terminal
                    :keys (((:control #\x) (:control #\c)))
                    :help "C-x C-c Exit"
                    :help-order 37)
      (command-spec nil execute-extended-command
                    :keys ((:alt #\x))
                    :help "M-x Command"
                    :help-order 1)))
