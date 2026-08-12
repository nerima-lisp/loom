;;;; src/application/event-loop-control.lisp
;;;;
;;;; Event-loop control helpers that do not own the main loop itself:
;;;; terminal sizing, background-work detection, and input wait policy.
(in-package #:loom)

(defun %initial-terminal-size ()
  "Return (VALUES WIDTH HEIGHT) for the controlling terminal via
CL-TTY-KIT:TERMINAL-SIZE, falling back to 80x24 when the size is unavailable
(e.g. *STANDARD-INPUT* is not a real terminal)."
  (multiple-value-bind (columns rows) (cl-tty-kit:terminal-size)
    (values (or columns 80) (or rows 24))))

(defun %poll-terminal-resize (renderer last-width last-height)
  "Check CL-TTY-KIT:TERMINAL-SIZE against LAST-WIDTH/LAST-HEIGHT and, on a
change, resize RENDERER via LOOM-RENDERER-RESIZE. Returns the (VALUES WIDTH
HEIGHT) to track as the last-seen size from now on -- LAST-WIDTH/LAST-HEIGHT
unchanged when the terminal size could not be read or has not changed."
  (multiple-value-bind (width height) (cl-tty-kit:terminal-size)
    (if (and width height (or (/= width last-width) (/= height last-height)))
        (progn
          (loom-renderer-resize renderer width height)
          (loom/feature/terminal:resize-terminal-sessions
           width height *editor-state*)
          (values width height))
        (values last-width last-height))))

(defparameter *event-loop-poll-interval* 0.05
  "Maximum seconds between background terminal and auto-save polls.

The interval is only used while there is background work that needs a
periodic turn.  With no live terminal session or auto-save target, the loop
keeps its original blocking read behavior.")

(defun %event-loop-background-work-p ()
  "Whether the event loop must wake up without a keyboard byte."
  (or (some #'loom/feature/terminal:terminal-session-alive-p
            (editor-state-terminal-sessions *editor-state*))
      (editor-state-auto-save-mode-p *editor-state*)
      (editor-state-auto-save-buffers *editor-state*)))

(defun %wait-for-editor-input ()
  "Wait for input, or return NIL after the background poll interval.

CL-TTY-KIT's descriptor wait lets PTY output and auto-save timers make
progress even when the user is idle.  Non-file streams used by tests and
embedding callers do not have a descriptor; those retain the old blocking
read semantics instead of making the event loop depend on a particular
stream implementation."
  (if (not (%event-loop-background-work-p))
      t
      (handler-case
          (cl-tty-kit:fd-wait
           (cl-tty-kit:stream-fd *standard-input*)
           :input
           *event-loop-poll-interval*)
        (error () t))))
