(in-package #:loom)

(defun %main-exit-code (&optional (argv (uiop:raw-command-line-arguments)))
  "Return the CLI exit code for ARGV without terminating the current process."
  (if (equal (rest argv) (list "--dump-catalog"))
      (progn
        (write-line (loom/core/command:command-catalog-json))
        0)
      (cl-cli:run-app *loom-app* :argv argv)))

(defun main ()
  "Dispatch UIOP's raw command-line arguments through *LOOM-APP* and exit."
  (uiop:quit (%main-exit-code)))
