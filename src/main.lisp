(in-package #:loom)

(defun %main-exit-code (&optional (argv (uiop:raw-command-line-arguments)))
  "Return the CLI exit code for ARGV without terminating the current process."
  (let ((arguments
          (if (and (= (length argv) 2)
                   (stringp (first argv))
                   (string= (or (pathname-name (pathname (first argv))) "")
                            "loom"))
              (rest argv)
              argv)))
    (if (equal arguments '("--dump-catalog"))
        (progn
          (write-line (loom/application:command-catalog-json))
          0)
        (cl-cli:run-app *loom-app* :argv argv))))

(defun main ()
  "Dispatch UIOP's raw command-line arguments through *LOOM-APP* and exit."
  (uiop:quit (%main-exit-code)))
