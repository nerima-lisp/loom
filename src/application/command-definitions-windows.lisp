;;;; src/application/command-definitions-windows.lisp
;;;;
;;;; Declarative command catalogue for window and workspace commands.
(in-package #:loom)

(define-command-spec-groups *windows-command-spec-groups*
  (command-spec-group "windows and workspaces"
      (command-spec "split-window-below" loom/feature/window:split-window-below
                    :keys (((:control #\x) #\2)))
      (command-spec "split-window-right" loom/feature/window:split-window-right
                    :keys (((:control #\x) #\3)))
      (command-spec "other-window" loom/feature/window:other-window
                    :keys (((:control #\x) #\o)))
      (command-spec "delete-window" loom/feature/window:delete-window
                    :keys (((:control #\x) #\0)))
      (command-spec "delete-other-windows"
                    loom/feature/window:delete-other-windows
                    :keys (((:control #\x) #\1)))
      (command-spec "switch-to-buffer" loom/feature/window:switch-to-buffer
                    :keys (((:control #\x) #\b)))
      (command-spec "kill-buffer" loom/feature/window:kill-buffer
                    :keys (((:control #\x) #\k)))
      (command-spec "new-workspace" loom/feature/workspace:new-workspace
                    :keys (((:control #\x) #\t #\2)))
      (command-spec "switch-workspace" loom/feature/workspace:switch-workspace
                    :keys (((:control #\x) #\t #\o)))
      (command-spec "kill-workspace" loom/feature/workspace:kill-workspace
                    :keys (((:control #\x) #\t #\k)))
      (command-spec "next-workspace" loom/feature/workspace:next-workspace
                    :keys (((:control #\x) #\t #\n)))
      (command-spec "previous-workspace"
                    loom/feature/workspace:previous-workspace
                    :keys (((:control #\x) #\t #\p)))))
