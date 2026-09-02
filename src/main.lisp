;;;; src/main.lisp
;;;;
;;;; Executable entry point. Startup, event-loop, and input-dispatch
;;;; responsibilities live under src/application/ so the composition root can
;;;; be tested independently from the binary trampoline.
(in-package #:loom)

(defun %main-exit-code (&optional (argv (uiop:raw-command-line-arguments)))
  "Return the CLI exit code for ARGV without terminating the current process."
  (cl-cli:run-app *loom-app* :argv argv))

(defun main ()
  "Dispatch UIOP's raw command-line arguments through *LOOM-APP* and exit."
  (uiop:quit (%main-exit-code)))
