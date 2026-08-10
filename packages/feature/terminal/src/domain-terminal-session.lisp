(in-package #:loom/feature/terminal)

(defstruct (terminal-session
            (:constructor %make-terminal-session
                (name program args directory buffer pty)))
  "A running PTY process and the Loom buffer displaying its screen."
  name
  program
  args
  directory
  buffer
  pty
  (screen (make-terminal-screen))
  (raw-output "" :type string)
  (alive-p t)
  exit-code)

(defun terminal-session-feed-output (session text)
  "Append PTY TEXT to SESSION and apply it to the terminal screen."
  (check-type text string)
  (setf (terminal-session-raw-output session)
        (concatenate 'string (terminal-session-raw-output session) text))
  (terminal-screen-feed (terminal-session-screen session) text)
  session)

(defun terminal-session-output (session)
  "Return SESSION's current visible screen as editor buffer text."
  (terminal-screen-text (terminal-session-screen session)))
