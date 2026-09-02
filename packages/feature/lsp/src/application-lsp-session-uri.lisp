;;;; packages/feature/lsp/src/application-lsp-session-uri.lisp
;;;
;;; URI and language metadata derived from file-backed LSP documents.
(in-package #:loom/feature/lsp)

(defun %lsp-uri-path-character-p (character)
  (or (char= character #\/)
      (or (and (char>= character #\0) (char<= character #\9))
          (and (char>= character #\A) (char<= character #\Z))
          (and (char>= character #\a) (char<= character #\z)))
      (find character "-._~:@!$&'()*+,;=" :test #'char=)))

(defun %lsp-uri-escape-path (path)
  (with-output-to-string (output)
    (loop for character across path
          do (if (%lsp-uri-path-character-p character)
                 (write-char character output)
                 (loop for octet across (%lsp-utf8-encode (string character))
                       do (format output "%~2,'0X" octet))))))

(defun lsp-path-uri (path)
  "Return the UTF-8 percent-encoded file URI for PATH."
  (format nil "file://~A"
          (%lsp-uri-escape-path (namestring (pathname path)))))

(defun %lsp-uri-hex-digit (character)
  (digit-char-p character 16))

(defun %lsp-uri-percent-escape-at (uri index)
  (when (and (char= (char uri index) #\%)
             (< (+ index 2) (length uri)))
    (let ((high (%lsp-uri-hex-digit (char uri (1+ index))))
          (low (%lsp-uri-hex-digit (char uri (+ index 2)))))
      (when (and high low)
        (values (+ (* high 16) low) 3)))))

(defun %lsp-uri-octet-at (uri index)
  (multiple-value-bind (octet consumed)
      (%lsp-uri-percent-escape-at uri index)
    (if consumed
        (values octet consumed)
        (values (char-code (char uri index)) 1))))

(defun %lsp-uri-decode-octets (uri)
  (let ((octets (make-array 0 :element-type '(unsigned-byte 8)
                              :adjustable t :fill-pointer 0))
        (index 7))
    (loop while (< index (length uri))
          do (multiple-value-bind (octet consumed)
                 (%lsp-uri-octet-at uri index)
               (vector-push-extend octet octets)
               (incf index consumed)))
    (coerce octets '(simple-array (unsigned-byte 8) (*)))))

(defun lsp-uri-path (uri)
  "Return the filesystem path named by a file URI, or NIL otherwise."
  (when (and (stringp uri) (uiop:string-prefix-p "file://" uri))
    (%lsp-utf8-decode (%lsp-uri-decode-octets uri))))

(defun %lsp-language-id (path)
  (let ((type (string-downcase (or (pathname-type (pathname path)) ""))))
    (if (member type '("lisp" "cl" "asd") :test #'string=)
        "common-lisp"
        (if (plusp (length type)) type "plaintext"))))
