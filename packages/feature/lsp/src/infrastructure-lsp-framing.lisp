;;;; packages/feature/lsp/src/infrastructure-lsp-framing.lisp
;;;;
;;;; Pure UTF-8 and Content-Length framing for the LSP transport boundary.
;;;; It has no process or thread state; UTF-8 and header helpers live in the
;;;; support file, while this file keeps the public framing API.
(in-package #:loom/feature/lsp)

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

(defun %lsp-frame-body-range (octets header-end header)
  (let ((body-length (%lsp-content-length header)))
    (unless body-length
      (error "LSP frame has no Content-Length header"))
    (when (minusp body-length)
      (error "LSP frame has a negative Content-Length: ~D" body-length))
    (let ((body-start (+ header-end 4))
          (body-end (+ header-end 4 body-length)))
      (if (> body-end (length octets))
          (values nil nil :incomplete)
          (values body-start body-end :complete)))))

(defun loom-lsp-frame-decode (octets)
  "Decode the first LSP frame in OCTETS.

Returns three values: the JSON string, the number of consumed octets, and one
of :COMPLETE or :INCOMPLETE.  Malformed headers and invalid UTF-8 signal an
error; an incomplete frame is a normal result for a streaming reader."
  (check-type octets (vector (unsigned-byte 8)))
  (let ((header-end (%lsp-find-header-end octets)))
    (unless header-end
      (return-from loom-lsp-frame-decode (values nil 0 :incomplete)))
    (multiple-value-bind (body-start body-end status)
        (%lsp-frame-body-range
         octets header-end (%lsp-header-string (subseq octets 0 header-end)))
      (if (eq status :incomplete)
          (values nil 0 status)
          (values (%lsp-utf8-decode (subseq octets body-start body-end))
                  body-end
                  status)))))
