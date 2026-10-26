(in-package #:loom/feature/terminal)

(defun terminal-event-loop-tick (session current-time)
  (declare (ignore session current-time))
  (poll-terminal-sessions *editor-state*))

(defun terminal-event-loop-resize (session columns rows)
  (declare (ignore session))
  (resize-terminal-sessions columns rows *editor-state*))
