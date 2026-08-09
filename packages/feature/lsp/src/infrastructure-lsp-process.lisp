;;;; packages/feature/lsp/src/infrastructure-lsp-process.lisp
;;;;
;;;; Infrastructure adapters for JSON-RPC framing and a language-server child
;;;; process.  The process reader is asynchronous: the editor's main lane
;;;; only calls the non-blocking RECEIVE operation while rendering a frame.
(in-package #:loom)

(defun %lsp-utf8-encode (string)
  (let ((octets (make-array 0 :element-type '(unsigned-byte 8)
                            :adjustable t :fill-pointer 0)))
    (flet ((emit (octet) (vector-push-extend octet octets)))
      (loop for character across string
            for code = (char-code character)
            do (cond
                 ((<= code #x7F)
                  (emit code))
                 ((<= code #x7FF)
                  (emit (+ #xC0 (ash code -6)))
                  (emit (+ #x80 (logand code #x3F))))
                 ((<= code #xFFFF)
                  (when (<= #xD800 code #xDFFF)
                    (error "Cannot encode a UTF-8 surrogate code point: ~S"
                           code))
                  (emit (+ #xE0 (ash code -12)))
                  (emit (+ #x80 (logand (ash code -6) #x3F)))
                  (emit (+ #x80 (logand code #x3F))))
                 ((<= code #x10FFFF)
                  (emit (+ #xF0 (ash code -18)))
                  (emit (+ #x80 (logand (ash code -12) #x3F)))
                  (emit (+ #x80 (logand (ash code -6) #x3F)))
                  (emit (+ #x80 (logand code #x3F))))
                 (t
                  (error "Cannot encode a Unicode code point: ~S" code)))))
    octets))

(defun %lsp-utf8-decode (octets)
  (with-output-to-string (output)
    (loop with index = 0
          while (< index (length octets))
          do (let* ((first (aref octets index))
                    (width (cond
                             ((<= first #x7F) 1)
                             ((<= #xC2 first #xDF) 2)
                             ((<= #xE0 first #xEF) 3)
                             ((<= #xF0 first #xF4) 4)
                             (t (error "Invalid UTF-8 leading byte: ~X" first))))
                    (code (logand first
                                  (case width
                                    (1 #x7F)
                                    (2 #x1F)
                                    (3 #x0F)
                                    (4 #x07)))))
               (when (> (+ index width) (length octets))
                 (error "Truncated UTF-8 sequence"))
               (loop for offset from 1 below width
                     for byte = (aref octets (+ index offset))
                     do (unless (<= #x80 byte #xBF)
                          (error "Invalid UTF-8 continuation byte: ~X" byte))
                        (setf code (+ (ash code 6) (logand byte #x3F))))
               (when (or (and (= width 3) (< code #x800))
                         (and (= width 4) (< code #x10000))
                         (<= #xD800 code #xDFFF)
                         (> code #x10FFFF))
                 (error "Invalid UTF-8 code point: ~X" code))
               (write-char (or (code-char code)
                               (error "Unknown Unicode code point: ~X" code))
                           output)
               (incf index width)))))

(defun %lsp-header-octets (string)
  (let ((octets (make-array (length string)
                            :element-type '(unsigned-byte 8))))
    (loop for character across string
          for index from 0
          for code = (char-code character)
          do (unless (<= code #x7F)
               (error "LSP header is not ASCII: ~S" string))
             (setf (aref octets index) code))
    octets))

(defun %lsp-find-header-end (octets)
  (loop for index from 0 below (- (length octets) 3)
        when (and (= (aref octets index) 13)
                  (= (aref octets (+ index 1)) 10)
                  (= (aref octets (+ index 2)) 13)
                  (= (aref octets (+ index 3)) 10))
          do (return index)))

(defun %lsp-header-string (octets)
  (with-output-to-string (output)
    (loop for octet across octets do (write-char (code-char octet) output))))

(defun %lsp-content-length (header)
  (let ((length-value nil))
    (loop with start = 0
          for end = (or (position #\Newline header :start start)
                        (length header))
          for line = (string-trim '(#\Space #\Tab #\Return)
                                  (subseq header start end))
          do (when (plusp (length line))
               (let ((colon (position #\: line)))
                 (unless colon
                   (error "Invalid LSP header line: ~S" line))
                 (let ((name (string-trim '(#\Space #\Tab)
                                          (subseq line 0 colon)))
                       (value (string-trim '(#\Space #\Tab #\Return)
                                           (subseq line (1+ colon)))))
                   (when (string-equal name "Content-Length")
                     (when length-value
                       (error "Duplicate Content-Length header"))
                     (setf length-value
                           (handler-case
                               (parse-integer value :junk-allowed nil)
                             (error ()
                               (error "Invalid Content-Length: ~S" value))))))))
             (if (= end (length header))
                 (return length-value)
                 (setf start (1+ end))))))

(defun loom-lsp-frame-encode (json)
  "Encode a JSON string as an LSP Content-Length framed octet vector."
  (check-type json string)
  (let* ((body (%lsp-utf8-encode json))
         (header (%lsp-header-octets
                  (format nil "Content-Length: ~D~C~C~C~C"
                          (length body) #\Return #\Newline #\Return #\Newline)))
         (frame (make-array (+ (length header) (length body))
                            :element-type '(unsigned-byte 8))))
    (replace frame header)
    (replace frame body :start1 (length header))
    frame))

(defun loom-lsp-frame-decode (octets)
  "Decode the first LSP frame in OCTETS.

Returns three values: the JSON string, the number of consumed octets, and one
of :COMPLETE or :INCOMPLETE.  Malformed headers and invalid UTF-8 signal an
error; an incomplete frame is a normal result for a streaming reader."
  (check-type octets vector)
  (let ((header-end (%lsp-find-header-end octets)))
    (unless header-end
      (return-from loom-lsp-frame-decode (values nil 0 :incomplete)))
    (let* ((header (%lsp-header-string (subseq octets 0 header-end)))
           (body-length (%lsp-content-length header)))
      (unless body-length
        (error "LSP frame has no Content-Length header"))
      (let* ((body-start (+ header-end 4))
             (body-end (+ body-start body-length)))
        (when (> body-end (length octets))
          (return-from loom-lsp-frame-decode
            (values nil 0 :incomplete)))
        (values (%lsp-utf8-decode (subseq octets body-start body-end))
                body-end
                :complete)))))

(defgeneric lsp-transport-send (transport json)
  (:documentation "Send one JSON message over an LSP transport."))

(defgeneric lsp-transport-receive (transport)
  (:documentation "Return one received JSON message without blocking, or NIL."))

(defgeneric lsp-transport-close (transport)
  (:documentation "Close an LSP transport and release its resources."))

(defstruct (lsp-process
            (:constructor %make-lsp-process
                (process input output error-output executor result-channel)))
  process
  input
  output
  error-output
  executor
  result-channel
  (closed-p nil))

(defun %lsp-process-read-output (process channel)
  (let ((buffer (make-array 0 :element-type '(unsigned-byte 8)
                            :adjustable t :fill-pointer 0))
        (stream (lsp-process-output process)))
    (loop for byte = (read-byte stream nil nil)
          while byte
          do (vector-push-extend byte buffer)
             (loop
               (multiple-value-bind (json used status)
                   (loom-lsp-frame-decode buffer)
                 (cond
                   ((eq status :incomplete) (return))
                   ((eq status :complete)
                    (cl-concurrent-kit:send channel json)
                    (setf buffer
                          (make-array (- (length buffer) used)
                                      :element-type '(unsigned-byte 8)
                                      :initial-contents (subseq buffer used))))
                   (t (return))))))
    (ignore-errors
      (cl-concurrent-kit:send channel nil))))

(defun %lsp-process-drain-errors (process)
  (loop for byte = (read-byte (lsp-process-error-output process) nil nil)
        while byte))

(defun make-lsp-process (command &key directory)
  "Launch COMMAND as an LSP server using binary streams.

COMMAND is passed to UIOP's shell launcher, so this adapter intentionally has
the same trust boundary as the user-init and Lisp evaluation features."
  (let* ((info (uiop:launch-program
                command
                :shell t
                :directory directory
                :input :stream
                :output :stream
                :error-output :stream
                :element-type '(unsigned-byte 8)))
         (channel (cl-concurrent-kit:make-channel :buffer-size 128))
         (executor (cl-concurrent-kit:make-executor
                    :size 2
                    :name "loom lsp process"
                    :queue-capacity 2))
         (process (%make-lsp-process
                   info
                   (uiop:process-info-input info)
                   (uiop:process-info-output info)
                   (uiop:process-info-error-output info)
                   executor
                   channel)))
    (handler-case
        (progn
          (multiple-value-bind (promise accepted)
              (cl-concurrent-kit:try-submit
               executor
               (lambda () (%lsp-process-read-output process channel)))
            (declare (ignore promise))
            (unless accepted (error "Could not start the LSP output reader")))
          (multiple-value-bind (promise accepted)
              (cl-concurrent-kit:try-submit
               executor
               (lambda () (%lsp-process-drain-errors process)))
            (declare (ignore promise))
            (unless accepted (error "Could not start the LSP error reader")))
          process)
      (error (condition)
        (lsp-transport-close process)
        (error condition)))))

(defmethod lsp-transport-send ((transport lsp-process) json)
  (when (lsp-process-closed-p transport)
    (error "LSP process transport is closed"))
  (write-sequence (loom-lsp-frame-encode json) (lsp-process-input transport))
  (finish-output (lsp-process-input transport))
  json)

(defmethod lsp-transport-receive ((transport lsp-process))
  (multiple-value-bind (result ready closed)
      (cl-concurrent-kit:try-recv (lsp-process-result-channel transport))
    (declare (ignore closed))
    (when ready result)))

(defmethod lsp-transport-close ((transport lsp-process))
  (unless (lsp-process-closed-p transport)
    (setf (lsp-process-closed-p transport) t)
    (ignore-errors (close (lsp-process-input transport)))
    (ignore-errors (uiop:terminate-process (lsp-process-process transport)))
    (ignore-errors (close (lsp-process-output transport)))
    (ignore-errors (close (lsp-process-error-output transport)))
    (unwind-protect
        (ignore-errors
          (cl-concurrent-kit:shutdown-executor
           (lsp-process-executor transport)
           :wait t
           :cancel-pending t))
      (cl-concurrent-kit:close-channel
       (lsp-process-result-channel transport))))
  transport)
