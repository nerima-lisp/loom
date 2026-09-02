;;;; packages/feature/lsp/src/infrastructure-lsp-transport-support.lisp
;;;;
;;;; Internal helpers for the LSP child-process transport.
(in-package #:loom/feature/lsp)

(defun %lsp-buffer-after-frame (buffer used)
  (let ((remaining-length (- (length buffer) used)))
    (make-array remaining-length
                :element-type '(unsigned-byte 8)
                :adjustable t
                :fill-pointer remaining-length
                :initial-contents (subseq buffer used))))

(defun %lsp-decode-complete-frames (buffer)
  (let ((messages nil)
        (remaining buffer))
    (loop
      (multiple-value-bind (json used status)
          (loom-lsp-frame-decode remaining)
        (ecase status
          (:incomplete
           (return (values (nreverse messages) remaining)))
          (:complete
           (push json messages)
           (setf remaining (%lsp-buffer-after-frame remaining used))))))))

(defun %lsp-read-stream-frames (stream on-message)
  (let ((buffer (make-array 0 :element-type '(unsigned-byte 8)
                            :adjustable t :fill-pointer 0))
        (message-count 0))
    (loop for byte = (read-byte stream nil nil)
          while byte
          do (vector-push-extend byte buffer)
             (multiple-value-bind (messages remaining)
                 (%lsp-decode-complete-frames buffer)
               (dolist (message messages)
                 (funcall on-message message)
                 (incf message-count))
               (setf buffer remaining)))
    (values message-count buffer)))

(defun %lsp-process-read-output (process channel)
  (%lsp-read-stream-frames
   (lsp-process-output process)
   (lambda (message)
     (cl-concurrent-kit:send channel message)))
  (ignore-errors
    (cl-concurrent-kit:send channel nil)))

(defun %lsp-process-drain-errors (process)
  (loop for byte = (read-byte (lsp-process-error-output process) nil nil)
        while byte))
