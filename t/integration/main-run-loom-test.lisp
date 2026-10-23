(in-package #:loom/test)

(progn
  (defvar *run-loom-test-init-loaded* nil)

  (defun %with-isolated-run-loom-home (thunk)
    (host-kit:with-temporary-directory (home)
      (let* ((init-path (merge-pathnames ".loom/init.lisp" home))
             (original-getenv (function host-kit:getenv))
             (*run-loom-test-init-loaded* nil)
             (override-looked-up nil)
             (*standard-output* (make-string-output-stream)))
        (ensure-directories-exist init-path)
        (host-kit:write-file-string
         "(setf loom/test::*run-loom-test-init-loaded* t)"
         init-path)
        (with-replaced-function
            (host-kit:getenv
             (lambda (name)
               (cond ((string= name "HOME") (namestring home))
                     ((string= name "LOOM_INIT_FILE")
                      (setf override-looked-up t)
                      (namestring init-path))
                     (t (funcall original-getenv name)))))
          (funcall thunk))
        (expect *run-loom-test-init-loaded* :to-be t)
        (expect override-looked-up :to-be-truthy)
        (expect (get-output-stream-string *standard-output*)
                :to-contain
                (format nil "~C[?1049h" (code-char 27))))))

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
                (%with-isolated-run-loom-home
                 (lambda ()
                   (expect (loom::%run-loom invocation :fd fd) :to-equal 0)))))
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
                (%with-isolated-run-loom-home
                 (lambda ()
                   (let ((*error-output* (make-string-output-stream)))
                     (with-replaced-function
                         (loom::%run-event-loop
                          (lambda (output-stream input-stream)
                            (declare (ignore output-stream input-stream))
                            (error "event loop failed")))
                       (expect (loom::%run-loom invocation :fd fd) :to-equal 1))
                     (expect (get-output-stream-string *error-output*)
                             :to-contain "event loop failed"))))))
          (cl-tty-kit:close-pty pty))))))
