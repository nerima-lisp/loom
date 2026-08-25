;;;; src/main.lisp
;;;;
;;;; Executable entry point. Startup, event-loop, and input-dispatch
;;;; responsibilities live under src/application/ so the composition root can
;;;; be tested independently from the binary trampoline.
(in-package #:loom)

(defun %main-exit-code (&optional (argv sb-ext:*posix-argv*))
  "Return the CLI exit code for ARGV without terminating the current process."
  (cl-cli:run-app *loom-app* :argv argv))

(defun main ()
  "Dispatch SB-EXT:*POSIX-ARGV* through *LOOM-APP* and exit with its code."
  (sb-ext:exit :code (%main-exit-code)))
