(in-package #:loom/feature/terminal)

(eval-when (:load-toplevel :execute)
  (register-session-hook :tick
                         :feature/terminal
                         (function terminal-event-loop-tick))
  (register-session-hook :resize
                         :feature/terminal
                         (function terminal-event-loop-resize)))
