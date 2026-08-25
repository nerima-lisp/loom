(in-package #:loom/test)

(defclass %lsp-byte-stream (sb-gray:fundamental-binary-input-stream)
  ((octets :initarg :octets :reader %lsp-byte-stream-octets)
   (position :initform 0 :accessor %lsp-byte-stream-position)))

(defmethod sb-gray:stream-read-byte ((stream %lsp-byte-stream))
  (let ((position (%lsp-byte-stream-position stream))
        (octets (%lsp-byte-stream-octets stream)))
    (if (< position (length octets))
        (prog1 (aref octets position)
          (incf (%lsp-byte-stream-position stream)))
        :eof)))

(defun %make-lsp-byte-stream (octets)
  (make-instance '%lsp-byte-stream :octets octets))

(defclass %lsp-output-byte-stream (sb-gray:fundamental-binary-output-stream)
  ((octets :initform (make-array 0
                                 :element-type '(unsigned-byte 8)
                                 :adjustable t
                                 :fill-pointer 0)
           :reader %lsp-output-byte-stream-octets)))

(defmethod sb-gray:stream-write-byte ((stream %lsp-output-byte-stream) byte)
  (vector-push-extend byte (%lsp-output-byte-stream-octets stream))
  byte)

(defmethod stream-element-type ((stream %lsp-output-byte-stream))
  (declare (ignore stream))
  '(unsigned-byte 8))

(defun %make-lsp-output-byte-stream ()
  (make-instance '%lsp-output-byte-stream))

(defun %make-test-lsp-process ()
  (loom/feature/lsp::%make-lsp-process
   nil nil nil nil nil
   (cl-concurrent-kit:make-channel :buffer-size 1)))

(describe
  "LSP transport readers"
  (it "decodes multiple framed messages from a child output stream"
    (let* ((first (loom/feature/lsp::loom-lsp-frame-encode "{\"id\":1}"))
           (second (loom/feature/lsp::loom-lsp-frame-encode "{\"id\":2}"))
           (octets (make-array (+ (length first) (length second))
                               :element-type '(unsigned-byte 8)))
           (channel (cl-concurrent-kit:make-channel :buffer-size 3))
           (process (loom/feature/lsp::%make-lsp-process
                     nil nil (%make-lsp-byte-stream octets) nil nil channel)))
      (replace octets first)
      (replace octets second :start1 (length first))
      (loom/feature/lsp::%lsp-process-read-output process channel)
      (expect (cl-concurrent-kit:recv channel) :to-equal "{\"id\":1}")
      (expect (cl-concurrent-kit:recv channel) :to-equal "{\"id\":2}")
      (expect (cl-concurrent-kit:recv channel) :to-be nil)))
  (it "drains all bytes from the child error stream"
    (let* ((octets (make-array 3 :element-type '(unsigned-byte 8)
                               :initial-contents '(1 2 3)))
           (process (loom/feature/lsp::%make-lsp-process
                     nil nil nil (%make-lsp-byte-stream octets) nil nil)))
      (expect (loom/feature/lsp::%lsp-process-drain-errors process)
              :to-be nil)
      (expect (%lsp-byte-stream-position
              (loom/feature/lsp::lsp-process-error-output process))
              :to-equal 3))))

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
              :to-be process))))

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
