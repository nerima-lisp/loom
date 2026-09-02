;;;; packages/feature/lsp/src/infrastructure-lsp-transport.lisp
;;;;
;;;; Infrastructure boundary for a language-server child process.  The process
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

(defun %lsp-process-readers (process channel)
  (list (lambda () (%lsp-process-read-output process channel))
        (lambda () (%lsp-process-drain-errors process))))

(defun %start-lsp-process-readers (process executor channel)
  (dolist (reader (%lsp-process-readers process channel))
    (multiple-value-bind (promise accepted)
        (cl-concurrent-kit:try-submit executor reader)
      (declare (ignore promise))
      (unless accepted (error "Could not start the LSP process reader"))))
  process)

(defun %close-lsp-resources (info input output error-output executor channel)
  (ignore-errors (close input))
  (when info
    (ignore-errors (uiop:terminate-process info)))
  (ignore-errors (close output))
  (ignore-errors (close error-output))
  (unwind-protect
       (when executor
         (ignore-errors
           (cl-concurrent-kit:shutdown-executor
            executor :wait t :cancel-pending t)))
    (when channel
      (ignore-errors (cl-concurrent-kit:close-channel channel)))))

(defun %cleanup-lsp-launch (info executor channel)
  (%close-lsp-resources
   info
   (when info (uiop:process-info-input info))
   (when info (uiop:process-info-output info))
   (when info (uiop:process-info-error-output info))
   executor
   channel))

(defun %launch-lsp-process (command directory)
  (let* ((info (uiop:launch-program
                command :shell t :directory directory
                :input :stream :output :stream :error-output :stream
                :element-type '(unsigned-byte 8)))
         (channel (cl-concurrent-kit:make-channel :buffer-size 128))
         (executor (cl-concurrent-kit:make-executor
                    :size 2 :name "loom lsp process" :queue-capacity 2))
         (process (%make-lsp-process
                   info
                   (uiop:process-info-input info)
                   (uiop:process-info-output info)
                   (uiop:process-info-error-output info)
                   executor
                   channel)))
    (values process info executor channel)))

(defun make-lsp-process (command &key directory)
  "Launch COMMAND as an LSP server using binary streams.

COMMAND is passed to UIOP's shell launcher, so this boundary intentionally has
the same trust boundary as the user-init and Lisp evaluation features."
  (let ((info nil)
        (process nil)
        (channel nil)
        (executor nil))
    (handler-case
        (progn
          (multiple-value-setq (process info executor channel)
            (%launch-lsp-process command directory))
          (%start-lsp-process-readers process executor channel))
      (error (condition)
        (when process
          (lsp-transport-close process))
        (when (and info (null process))
          (%cleanup-lsp-launch info executor channel))
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
    (%close-lsp-resources
     (lsp-process-process transport)
     (lsp-process-input transport)
     (lsp-process-output transport)
     (lsp-process-error-output transport)
     (lsp-process-executor transport)
     (lsp-process-result-channel transport)))
  transport)
