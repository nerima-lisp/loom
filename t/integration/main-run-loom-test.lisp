;;;; t/integration/main-run-loom-test.lisp
(in-package #:loom/test)

(describe
  "%main-exit-code"
  (it
    "passes the application and explicit argv to the CLI runner"
    (let ((application nil)
          (arguments nil))
      (with-replaced-function
          (cl-cli:run-app
           (lambda (app &key argv)
             (setf application app
                   arguments argv)
             17))
      (expect (loom::%main-exit-code '("loom" "--version")) :to-equal 17))
      (expect application :to-be loom::*loom-app*)
      (expect arguments :to-equal '("loom" "--version")))))

(describe
  "%run-loom"
  (it
      "enables and restores raw mode against a real terminal descriptor, then returns 0"
      (let ((pty (cl-tty-kit:make-pty :program "/bin/sh")))
        (unwind-protect
            (let ((fd (sb-sys:fd-stream-fd (cl-tty-kit:pty-stream pty)))
                  (invocation (cl-cli:parse-argv loom::*loom-app* '("loom"))))
              (with-open-file (*standard-input* "/dev/null"
                                                :direction :input
                                                :element-type '(unsigned-byte 8))
                (expect (loom::%run-loom invocation :fd fd) :to-equal 0)))
          (cl-tty-kit:close-pty pty))))

    (it
      "reports an event-loop failure and returns 1"
      (let ((pty (cl-tty-kit:make-pty :program "/bin/sh")))
        (unwind-protect
            (let ((fd (sb-sys:fd-stream-fd (cl-tty-kit:pty-stream pty)))
                  (invocation (cl-cli:parse-argv loom::*loom-app* '("loom"))))
              (with-open-file (*standard-input* "/dev/null"
                                                :direction :input
                                                :element-type '(unsigned-byte 8))
                (let ((*error-output* (make-string-output-stream)))
                  (with-replaced-function
                      (loom::%run-event-loop
                       (lambda (output-stream input-stream)
                         (declare (ignore output-stream input-stream))
                         (error "event loop failed")))
                    (expect (loom::%run-loom invocation :fd fd) :to-equal 1))
                  (expect (get-output-stream-string *error-output*)
                          :to-contain "event loop failed"))))
          (cl-tty-kit:close-pty pty)))))
