;;;; src/main.lisp
;;;;
;;;; Executable entry point. Startup, event-loop, and input-dispatch
;;;; responsibilities live under src/application/ so the composition root can
;;;; be tested independently from the binary trampoline.
(in-package #:loom)

(defun main ()
  "Dispatch SB-EXT:*POSIX-ARGV* through *LOOM-APP* and exit with its code."
  (sb-ext:exit :code (cl-cli:run-app *loom-app* :argv sb-ext:*posix-argv*)))
