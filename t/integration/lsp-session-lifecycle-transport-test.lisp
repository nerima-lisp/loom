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
