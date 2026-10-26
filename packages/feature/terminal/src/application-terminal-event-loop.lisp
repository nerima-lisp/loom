(in-package #:loom/feature/terminal)

(defun terminal-event-loop-background-work-p (state)
  "Whether STATE has a live terminal session that needs periodic polling."
  (some #'terminal-session-alive-p (editor-state-terminal-sessions state)))

