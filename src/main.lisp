(in-package #:loom)

(defun %cli-control-request-p (arguments &optional (options-ended-p nil))
  (when arguments
    (let ((argument (first arguments)))
      (cond
        ((and (not options-ended-p) (string= argument "--"))
         (%cli-control-request-p (rest arguments) t))
        ((and (not options-ended-p)
              (member argument
                      (list "--dump-catalog" "--help" "-h" "--version" "-V")
                      :test
                      (function string=))) t)
        ((and (not options-ended-p)
              (>= (length argument) 2)
              (string= argument "--" :end1 2)
              (not (position #\= argument))
              (eq (loom/core/editor-session:cli-option-value-kind argument)
                  :value))
         (%cli-control-request-p (cddr arguments) options-ended-p))
        (t (%cli-control-request-p (rest arguments) options-ended-p))))))

(defun %main-exit-code (&optional (argv (uiop:raw-command-line-arguments)))
  "Return the CLI exit code for ARGV without terminating the current process."
  (let ((arguments (rest argv)))
    (cond
      ((equal arguments (list "--dump-catalog"))
        (write-line (loom/core/command:command-catalog-json))
        0)
      ((%cli-control-request-p arguments)
       (cl-cli:run-app *loom-app* :argv argv))
      (t (handler-case
             (%run-loom (%parse-startup-context arguments))
           (cl-cli:cli-usage-error (condition)
             (format *error-output* "~&~A~%~%"
                     (cl-cli:cli-error-message condition))
             (cl-cli:print-app-help *loom-app* *error-output*)
             64))))))

(defun main ()
  "Dispatch UIOP's raw command-line arguments through the startup CLI boundary."
  (uiop:quit (%main-exit-code)))
