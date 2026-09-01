;;;; packages/feature/lsp/src/infrastructure-lsp-transport.lisp
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

(defun %start-lsp-process-readers (process executor channel)
  (dolist (reader (list (lambda () (%lsp-process-read-output process channel))
                        (lambda () (%lsp-process-drain-errors process))))
    (multiple-value-bind (promise accepted)
        (cl-concurrent-kit:try-submit executor reader)
      (declare (ignore promise))
      (unless accepted (error "Could not start the LSP process reader"))))
  process)

(defun %cleanup-lsp-launch (info executor channel)
  (when executor
    (ignore-errors
      (cl-concurrent-kit:shutdown-executor
       executor :wait t :cancel-pending t)))
  (when channel
    (ignore-errors (cl-concurrent-kit:close-channel channel)))
  (when info
    (ignore-errors (close (uiop:process-info-input info)))
    (ignore-errors (uiop:terminate-process info))
    (ignore-errors (close (uiop:process-info-output info)))
    (ignore-errors (close (uiop:process-info-error-output info)))))

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

COMMAND is passed to UIOP's shell launcher, so this adapter intentionally has
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
