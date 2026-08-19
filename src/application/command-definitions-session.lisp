;;;; src/application/command-definitions-session.lisp
;;;;
;;;; Declarative command catalogue for session, bookmark, and register commands.
(in-package #:loom)

(define-command-spec-groups *session-command-spec-groups*
  (command-spec-group "session and registers"
      (command-spec "save-session" loom/feature/session:save-session
                    :keys (((:control #\x) #\r #\S))
                    :help "C-x r S Save session"
                    :help-order 17)
      (command-spec "load-session" loom/feature/session:load-session
                    :keys (((:control #\x) #\r #\l))
                    :help "C-x r l Load session"
                    :help-order 18)
      (command-spec "set-bookmark" set-bookmark
                    :keys (((:control #\x) #\r #\m))
                    :help "C-x r m Set bookmark"
                    :help-order 20)
      (command-spec "jump-to-bookmark" jump-to-bookmark
                    :keys (((:control #\x) #\r #\b))
                    :help "C-x r b Jump bookmark"
                    :help-order 21)
      (command-spec "delete-bookmark" delete-bookmark
                    :keys (((:control #\x) #\r #\d))
                    :help "C-x r d Delete bookmark"
                    :help-order 22)
      (command-spec "list-bookmarks" list-bookmarks)
      (command-spec "copy-to-register" loom/feature/register:copy-to-register
                    :keys (((:control #\x) #\r #\s))
                    :help "C-x r s Copy region to register"
                    :help-order 23)
      (command-spec "insert-register" loom/feature/register:insert-register
                    :keys (((:control #\x) #\r #\i))
                    :help "C-x r i Insert register"
                    :help-order 24)
      (command-spec "point-to-register" loom/feature/register:point-to-register
                    :keys (((:control #\x) #\r #\Space))
                    :help "C-x r SPC Point to register"
                    :help-order 25)
      (command-spec "jump-to-register" loom/feature/register:jump-to-register
                    :keys (((:control #\x) #\r #\j))
                    :help "C-x r j Jump to register"
                    :help-order 26)))
