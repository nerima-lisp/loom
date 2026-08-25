;;;; packages/feature/lsp/src/infrastructure-lsp-transport-support.lisp
;;;;
;;;; Internal helpers for the LSP child-process transport.
(in-package #:loom/feature/lsp)

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
                                      :adjustable t
                                      :fill-pointer (- (length buffer) used)
                                      :initial-contents (subseq buffer used))))
                   (t (return))))))
    (ignore-errors
      (cl-concurrent-kit:send channel nil))))

(defun %lsp-process-drain-errors (process)
  (loop for byte = (read-byte (lsp-process-error-output process) nil nil)
        while byte))
