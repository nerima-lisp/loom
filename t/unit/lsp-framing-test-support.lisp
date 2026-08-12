(in-package #:loom/test)

(defun %lsp-octets (&rest values)
  (make-array (length values)
              :element-type '(unsigned-byte 8)
              :initial-contents values))

(defun %lsp-raw-octets (string)
  (let ((octets (make-array (length string)
                            :element-type '(unsigned-byte 8))))
    (loop for character across string
          for index from 0
          do (setf (aref octets index) (char-code character)))
    octets))

(defun %lsp-raw-frame (header body)
  (let* ((header-octets (%lsp-raw-octets header))
         (frame (make-array (+ (length header-octets) (length body))
                            :element-type '(unsigned-byte 8))))
    (replace frame header-octets)
    (replace frame body :start1 (length header-octets))
    frame))

(defun %lsp-crlf ()
  (format nil "~C~C" #\Return #\Newline))
