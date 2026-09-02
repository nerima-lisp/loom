(in-package #:loom/test)

(describe
  "LSP transport state"
  (it "returns no message when its result channel is empty"
    (let ((process (%make-test-lsp-process)))
      (unwind-protect
           (expect (loom/feature/lsp::lsp-transport-receive process)
                   :to-be nil)
        (loom/feature/lsp::lsp-transport-close process))))
  (it "receives a queued message without touching the child process"
    (let ((process (%make-test-lsp-process)))
      (unwind-protect
           (progn
             (cl-concurrent-kit:send
              (loom/feature/lsp::lsp-process-result-channel process)
              "queued")
             (expect (loom/feature/lsp::lsp-transport-receive process)
                     :to-equal "queued")
             (expect (loom/feature/lsp::lsp-transport-receive process)
                     :to-be nil))
        (loom/feature/lsp::lsp-transport-close process))))
  (it "closes an already closed transport idempotently"
    (let ((process (%make-test-lsp-process)))
      (expect (loom/feature/lsp::lsp-transport-close process)
              :to-be process)
      (expect (loom/feature/lsp::lsp-transport-close process)
              :to-be process)))
  (it "tolerates a result channel closed by the reader"
    (let ((process (%make-test-lsp-process)))
      (cl-concurrent-kit:close-channel
       (loom/feature/lsp::lsp-process-result-channel process))
      (expect (loom/feature/lsp::lsp-transport-close process)
              :to-be process))))

(describe
  "LSP transport launch failures"
  (it "closes a partially launched process when readers cannot start"
    (let ((original-launch
            (symbol-function 'loom/feature/lsp::%launch-lsp-process))
          (original-readers
            (symbol-function 'loom/feature/lsp::%start-lsp-process-readers))
          (process (%make-test-lsp-process)))
      (unwind-protect
           (progn
             (setf (symbol-function 'loom/feature/lsp::%launch-lsp-process)
                   (lambda (command directory)
                     (declare (ignore command directory))
                     (values process nil nil
                             (loom/feature/lsp::lsp-process-result-channel
                              process))))
             (setf (symbol-function
                    'loom/feature/lsp::%start-lsp-process-readers)
                   (lambda (process executor channel)
                     (declare (ignore process executor channel))
                     (error "reader unavailable")))
             (signals error
               (loom/feature/lsp::make-lsp-process "unused"))
             (expect (loom/feature/lsp::lsp-process-closed-p process)
                     :to-be t))
        (setf (symbol-function 'loom/feature/lsp::%launch-lsp-process)
              original-launch
              (symbol-function 'loom/feature/lsp::%start-lsp-process-readers)
              original-readers)))))
  (it "signals when the reader executor rejects a reader"
    (let ((original-submit
            (symbol-function 'cl-concurrent-kit:try-submit))
          (process (%make-test-lsp-process)))
      (unwind-protect
           (progn
             (setf (symbol-function 'cl-concurrent-kit:try-submit)
                   (lambda (executor function)
                     (declare (ignore executor function))
                     (values nil nil)))
             (signals error
               (loom/feature/lsp::%start-lsp-process-readers
                process nil
                (loom/feature/lsp::lsp-process-result-channel process))))
        (setf (symbol-function 'cl-concurrent-kit:try-submit)
              original-submit))))
  (it "cleans up launch resources when process construction fails"
    (let ((original-launch
            (symbol-function 'loom/feature/lsp::%launch-lsp-process))
          (original-readers
            (symbol-function 'loom/feature/lsp::%start-lsp-process-readers))
          (original-cleanup
            (symbol-function 'loom/feature/lsp::%cleanup-lsp-launch))
          (cleaned nil))
      (unwind-protect
           (progn
             (setf (symbol-function 'loom/feature/lsp::%launch-lsp-process)
                   (lambda (command directory)
                     (declare (ignore command directory))
                     (values nil :launched-info :executor :channel)))
             (setf (symbol-function
                    'loom/feature/lsp::%start-lsp-process-readers)
                   (lambda (process executor channel)
                     (declare (ignore process executor channel))
                     (error "reader unavailable")))
             (setf (symbol-function 'loom/feature/lsp::%cleanup-lsp-launch)
                   (lambda (info executor channel)
                     (setf cleaned (list info executor channel))))
             (signals error
               (loom/feature/lsp::make-lsp-process "unused"))
             (expect cleaned :to-equal
                     '(:launched-info :executor :channel)))
        (setf (symbol-function 'loom/feature/lsp::%launch-lsp-process)
              original-launch
              (symbol-function 'loom/feature/lsp::%start-lsp-process-readers)
              original-readers
              (symbol-function 'loom/feature/lsp::%cleanup-lsp-launch)
              original-cleanup))))

