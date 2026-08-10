;;;; packages/feature/lsp/src/infrastructure-lsp-process.lisp
;;;;
;;;; Infrastructure adapter for a language-server child process.  The process
;;;; reader is asynchronous: the editor's main lane only calls the non-blocking
;;;; RECEIVE operation while rendering a frame.  Pure JSON-RPC framing lives in
;;;; infrastructure-lsp-framing.lisp.
(in-package #:loom/feature/lsp)

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

(defparameter +lsp-config-file-name+ ".loom-lsp"
  "The project-local file used to discover an LSP server command.")

(defun %lsp-config-command (contents)
  "Return the first non-empty, non-comment command line in CONTENTS.

Comment lines begin with `#` after leading whitespace.  The complete line is
preserved after trimming surrounding whitespace so shell commands can retain
their arguments and quoting."
  (when (stringp contents)
    (with-input-from-string (stream contents)
      (loop for line = (read-line stream nil nil)
            while line
            for candidate = (string-trim '(#\Space #\Tab #\Return) line)
            unless (or (zerop (length candidate))
                       (char= (char candidate 0) #\#))
              do (return candidate)))))

(defun lsp-discover-command (path)
  "Discover a project-local LSP command for PATH.

The nearest ancestor containing `.loom-lsp` is used.  Its first non-empty,
non-comment line is treated as a shell command.  Return three values: the
command, the project root, and the configuration pathname.  Return three NIL
values when no usable configuration is found.  Reading a malformed or
unreadable configuration is intentionally treated as no discovery so the
interactive command can continue to offer its explicit prompt."
  (let ((root
          (ignore-errors
            (loom/feature/project:project-root-for-path
             path
             (lambda (directory)
               (probe-file
                (merge-pathnames +lsp-config-file-name+ directory)))))))
    (if root
        (let* ((configuration
                 (merge-pathnames +lsp-config-file-name+ root))
               (contents (ignore-errors
                           (host-kit:read-file-string configuration)))
               (command (%lsp-config-command contents)))
          (if command
              (values command root configuration)
              (values nil nil nil)))
        (values nil nil nil))))

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
