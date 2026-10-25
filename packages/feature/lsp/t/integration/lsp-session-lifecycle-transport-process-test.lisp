(in-package #:loom/test)

(describe
  "LSP transport sending"
  (it "writes a framed message to a binary output stream"
    (let* ((output (%make-lsp-output-byte-stream))
           (process (loom/feature/lsp::%make-lsp-process
                     nil output nil nil nil
                     (cl-concurrent-kit:make-channel :buffer-size 1))))
      (unwind-protect
           (progn
             (expect (loom/feature/lsp::lsp-transport-send
                      process "{\"ok\":true}")
                     :to-equal
                     "{\"ok\":true}")
             (expect (equalp (%lsp-output-byte-stream-octets output)
                             (loom/feature/lsp::loom-lsp-frame-encode
                              "{\"ok\":true}"))
                     :to-be
                     t))
        (loom/feature/lsp::lsp-transport-close process))))

  (it "rejects sends after the transport is closed"
    (let ((process (%make-test-lsp-process)))
      (loom/feature/lsp::lsp-transport-close process)
      (signals error
        (loom/feature/lsp::lsp-transport-send process "{}")))))

(describe
  "LSP transport process"
  (it "round-trips a framed message through a child process"
    (when (%sandboxed-check-p)
      (skip "spawns a real \"cat\" child process; see checks.default's LOOM_SANDBOXED_CHECK in flake.nix"))
    (let ((process (loom/feature/lsp::make-lsp-process "cat"))
          (received nil))
      (unwind-protect
           (progn
             (loom/feature/lsp::lsp-transport-send process "{\"ok\":true}")
             (loop repeat 200
                   do (setf received
                            (loom/feature/lsp::lsp-transport-receive process))
                      (when received (return))
                      (sleep 0.01))
             (expect received :to-equal "{\"ok\":true}"))
        (loom/feature/lsp::lsp-transport-close process))
      (signals error
        (loom/feature/lsp::lsp-transport-send process "{\"ok\":false}"))
      (expect (loom/feature/lsp::lsp-transport-receive process)
              :to-be nil)
      (expect (loom/feature/lsp::lsp-transport-close process)
              :to-be process))))
