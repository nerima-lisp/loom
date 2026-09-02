(in-package #:loom/test)

(describe
  "LSP transport readers"
  (it "passes decoded messages to a continuation"
    (let* ((frame (loom/feature/lsp::loom-lsp-frame-encode "{\"id\":1}"))
           (messages nil)
           (count (loom/feature/lsp::%lsp-read-stream-frames
                   (%make-lsp-byte-stream frame)
                   (lambda (message)
                     (push message messages)))))
      (expect count :to-equal 1)
      (expect messages :to-equal '("{\"id\":1}"))))
  (it "returns an incomplete trailing buffer to the caller"
    (let* ((frame (loom/feature/lsp::loom-lsp-frame-encode "{\"id\":1}"))
           (partial (subseq frame 0 (1- (length frame))))
           (messages nil))
      (multiple-value-bind (count remainder)
          (loom/feature/lsp::%lsp-read-stream-frames
           (%make-lsp-byte-stream partial)
           (lambda (message)
             (push message messages)))
        (expect count :to-equal 0)
        (expect messages :to-be nil)
        (expect (length remainder) :to-be-greater-than 0))))
  (it "propagates malformed frames from the stream reader"
    (let* ((crlf (%lsp-crlf))
           (malformed (%lsp-raw-frame
                       (format nil "Content-Length nope~A~A" crlf crlf)
                       #())))
      (signals error
        (loom/feature/lsp::%lsp-read-stream-frames
         (%make-lsp-byte-stream malformed)
         (lambda (message)
           (declare (ignore message)))))))
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
  (it "finishes after an incomplete trailing frame and signals reader EOF"
    (let* ((complete (loom/feature/lsp::loom-lsp-frame-encode "{\"id\":1}"))
           (partial (subseq complete 0 (1- (length complete))))
           (octets (make-array (+ (length complete) (length partial))
                               :element-type '(unsigned-byte 8)))
           (channel (cl-concurrent-kit:make-channel :buffer-size 2))
           (process (loom/feature/lsp::%make-lsp-process
                     nil nil (%make-lsp-byte-stream octets) nil nil channel)))
      (replace octets complete)
      (replace octets partial :start1 (length complete))
      (loom/feature/lsp::%lsp-process-read-output process channel)
      (expect (cl-concurrent-kit:recv channel) :to-equal "{\"id\":1}")
      (expect (cl-concurrent-kit:recv channel) :to-be nil)))

