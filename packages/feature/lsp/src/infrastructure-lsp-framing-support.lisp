;;;; packages/feature/lsp/src/infrastructure-lsp-framing-support.lisp
;;;;
;;;; Internal UTF-8 helpers for LSP framing. Header parsing lives in
;;;; infrastructure-lsp-headers.lisp; public framing entry points stay in
;;;; infrastructure-lsp-framing.lisp.
(in-package #:loom/feature/lsp)

(defun %lsp-utf8-codepoint-width (code)
  (cond ((<= code #x7F) 1)
        ((<= code #x7FF) 2)
        ((<= code #xFFFF) 3)
        ((<= code #x10FFFF) 4)
        (t (error "Invalid UTF-8 code point: ~S" code))))

(defun %lsp-utf8-emit-continuation (octets code shift)
  (vector-push-extend (+ #x80 (logand (ash code (- shift)) #x3F)) octets))

(defun %lsp-utf8-leading-byte (code width)
  (+ (case width
       (1 0)
       (2 #xC0)
       (3 #xE0)
       (4 #xF0))
     (ash code (* -6 (1- width)))))

(defun %lsp-utf8-continuation-shifts (width)
  (case width
    (1 nil)
    (2 '(0))
    (3 '(6 0))
    (4 '(12 6 0))))

(defun %lsp-utf8-emit-codepoint (octets code)
  (let ((width (%lsp-utf8-codepoint-width code)))
    (when (and (= width 3) (<= #xD800 code #xDFFF))
      (error "Cannot encode a UTF-8 surrogate code point: ~S" code))
    (vector-push-extend (%lsp-utf8-leading-byte code width) octets)
    (dolist (shift (%lsp-utf8-continuation-shifts width))
      (%lsp-utf8-emit-continuation octets code shift))))

(defun %lsp-utf8-encode (string)
  (let ((octets (make-array 0 :element-type '(unsigned-byte 8)
                            :adjustable t :fill-pointer 0)))
    (loop for character across string
          do (%lsp-utf8-emit-codepoint octets (char-code character)))
    octets))

(defun %lsp-utf8-leading-byte-width (byte)
  (cond ((<= byte #x7F) 1)
        ((<= #xC2 byte #xDF) 2)
        ((<= #xE0 byte #xEF) 3)
        ((<= #xF0 byte #xF4) 4)
        (t (error "Invalid UTF-8 leading byte: ~X" byte))))

(defun %lsp-utf8-leading-byte-code (byte width)
  (logand byte (case width
                 (1 #x7F)
                 (2 #x1F)
                 (3 #x0F)
                 (4 #x07))))

(defun %lsp-utf8-read-continuation (octets index width code)
  (loop for offset from 1 below width
        for byte = (aref octets (+ index offset))
        do (unless (<= #x80 byte #xBF)
             (error "Invalid UTF-8 continuation byte: ~X" byte))
           (setf code (+ (ash code 6) (logand byte #x3F)))
        finally (return code)))

(defun %lsp-utf8-valid-codepoint-p (code width)
  (not (or (and (= width 3) (< code #x800))
           (and (= width 4) (< code #x10000))
           (<= #xD800 code #xDFFF)
           (> code #x10FFFF))))

(defun %lsp-utf8-sequence (octets index)
  (let* ((first (aref octets index))
         (width (%lsp-utf8-leading-byte-width first)))
    (when (> (+ index width) (length octets))
      (error "Truncated UTF-8 sequence"))
    (let ((code (%lsp-utf8-read-continuation
                 octets index width
                 (%lsp-utf8-leading-byte-code first width))))
      (unless (%lsp-utf8-valid-codepoint-p code width)
        (error "Invalid UTF-8 code point: ~X" code))
      (values code (+ index width)))))

(defun %lsp-utf8-decode (octets)
  (with-output-to-string (output)
    (loop with index = 0
          while (< index (length octets))
          do (multiple-value-bind (code next-index)
                 (%lsp-utf8-sequence octets index)
               (write-char (code-char code) output)
               (setf index next-index)))))
