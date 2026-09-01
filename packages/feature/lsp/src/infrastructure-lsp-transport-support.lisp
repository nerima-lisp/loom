;;;; packages/feature/lsp/src/infrastructure-lsp-transport-support.lisp
;;;;
;;;; Internal helpers for the LSP child-process transport.
(in-package #:loom/feature/lsp)

(defun %lsp-decode-complete-frames (buffer)
  (let ((messages nil)
        (remaining buffer))
    (loop
      (multiple-value-bind (json used status)
          (loom-lsp-frame-decode remaining)
        (cond
          ((eq status :incomplete)
           (return (values (nreverse messages) remaining)))
          ((eq status :complete)
           (push json messages)
           (setf remaining
                 (make-array (- (length remaining) used)
                             :element-type '(unsigned-byte 8)
                             :adjustable t
                             :fill-pointer (- (length remaining) used)
                             :initial-contents (subseq remaining used))))
          (t (return (values (nreverse messages) remaining))))))))

(defun %lsp-process-read-output (process channel)
  (let ((buffer (make-array 0 :element-type '(unsigned-byte 8)
                            :adjustable t :fill-pointer 0))
        (stream (lsp-process-output process)))
    (loop for byte = (read-byte stream nil nil)
          while byte
          do (vector-push-extend byte buffer)
             (multiple-value-bind (messages remaining)
                 (%lsp-decode-complete-frames buffer)
               (dolist (message messages)
                 (cl-concurrent-kit:send channel message))
               (setf buffer remaining)))
    (ignore-errors
      (cl-concurrent-kit:send channel nil))))

(defun %lsp-process-drain-errors (process)
  (loop for byte = (read-byte (lsp-process-error-output process) nil nil)
        while byte))
