(in-package #:loom/feature/terminal)

(defun terminal-event-loop-background-work-p (state)
  "Whether STATE has a live terminal session that needs periodic polling."
  (some #'terminal-session-alive-p (editor-state-terminal-sessions state)))

(defun terminal-event-loop-poll-sessions (state)
  "Poll STATE's terminal sessions at the event loop's rendering point."
  (poll-terminal-sessions state))

(defun terminal-event-loop-resize-sessions (columns rows state)
  "Resize STATE's terminal sessions after the renderer observes a new size."
  (resize-terminal-sessions columns rows state))
