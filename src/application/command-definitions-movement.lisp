;;;; src/application/command-definitions-movement.lisp
;;;;
;;;; Declarative command catalogue for movement commands.
(in-package #:loom)

(define-command-spec-groups *movement-command-spec-groups*
  (command-spec-group "movement"
      (command-spec "universal-argument" universal-argument
                    :keys ((:control #\u)))
      (command-spec "forward-char" forward-char :keys ((:control #\f)))
      (command-spec "backward-char" backward-char :keys ((:control #\b)))
      (command-spec "next-line" next-line :keys ((:control #\n)))
      (command-spec "previous-line" previous-line :keys ((:control #\p)))
      (command-spec "forward-word" forward-word :keys ((:alt #\f)))
      (command-spec "backward-word" backward-word :keys ((:alt #\b)))
      (command-spec "move-beginning-of-line" move-beginning-of-line
                    :keys ((:control #\a)))
      (command-spec "move-end-of-line" move-end-of-line :keys ((:control #\e)))
      (command-spec "beginning-of-buffer" beginning-of-buffer :keys ((:alt #\<)))
      (command-spec "end-of-buffer" end-of-buffer :keys ((:alt #\>)))
      (command-spec "scroll-up-command" scroll-up-command :keys ((:control #\v)))
      (command-spec "scroll-down-command" scroll-down-command :keys ((:alt #\v)))
      (command-spec "goto-line" goto-line :keys (((:alt #\g) #\g)))))
