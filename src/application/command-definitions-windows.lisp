(in-package #:loom)

(define-command-spec-groups *windows-command-spec-groups*
  (command-spec-group "windows and workspaces"
      (command-spec "split-window-below" loom/feature/window:split-window-below
                    :keys (((:control #\x) #\2))
                    :mutates NIL
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "split-window-right" loom/feature/window:split-window-right
                    :keys (((:control #\x) #\3))
                    :mutates NIL
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "other-window" loom/feature/window:other-window
                    :keys (((:control #\x) #\o))
                    :mutates NIL
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "delete-window" loom/feature/window:delete-window
                    :keys (((:control #\x) #\0))
                    :mutates NIL
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "delete-other-windows"
                    loom/feature/window:delete-other-windows
                    :keys (((:control #\x) #\1))
                    :mutates NIL
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "switch-to-buffer" loom/feature/buffers:switch-to-buffer
                    :keys (((:control #\x) #\b))
                    :mutates NIL
                    :prompts (:completion)
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "kill-buffer" loom/feature/buffers:kill-buffer
                    :keys (((:control #\x) #\k))
                    :mutates NIL
                    :prompts (:completion :free-string)
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "new-workspace" loom/feature/workspace:new-workspace
                    :keys (((:control #\x) #\t #\2))
                    :mutates NIL
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "switch-workspace" loom/feature/workspace:switch-workspace
                    :keys (((:control #\x) #\t #\o))
                    :mutates NIL
                    :prompts (:completion)
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "kill-workspace" loom/feature/workspace:kill-workspace
                    :keys (((:control #\x) #\t #\k))
                    :mutates NIL
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "next-workspace" loom/feature/workspace:next-workspace
                    :keys (((:control #\x) #\t #\n))
                    :mutates NIL
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "previous-workspace"
                    loom/feature/workspace:previous-workspace
                    :keys (((:control #\x) #\t #\p))
                    :mutates NIL
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))))
