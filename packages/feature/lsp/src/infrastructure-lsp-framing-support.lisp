;;;; packages/feature/lsp/src/infrastructure-lsp-framing-support.lisp
;;;;
;;;; Internal UTF-8 and header helpers for LSP framing. Public framing entry
;;;; points stay in infrastructure-lsp-framing.lisp.
(in-package #:loom/feature/lsp)

(defun %lsp-utf8-codepoint-width (code)
  (cond ((<= code #x7F) 1)
        ((<= code #x7FF) 2)
        ((<= code #xFFFF) 3)
        ((<= code #x10FFFF) 4)
        (t (error "Invalid UTF-8 code point: ~S" code))))

(defun %lsp-utf8-emit-continuation (octets code shift)
  (vector-push-extend (+ #x80 (logand (ash code (- shift)) #x3F)) octets))

(defun %lsp-utf8-emit-codepoint (octets code)
  (let ((width (%lsp-utf8-codepoint-width code)))
    (when (and (= width 3) (<= #xD800 code #xDFFF))
      (error "Cannot encode a UTF-8 surrogate code point: ~S" code))
    (case width
      (1 (vector-push-extend code octets))
      (2
       (vector-push-extend (+ #xC0 (ash code -6)) octets)
       (%lsp-utf8-emit-continuation octets code 0))
      (3
       (vector-push-extend (+ #xE0 (ash code -12)) octets)
       (%lsp-utf8-emit-continuation octets code 6)
       (%lsp-utf8-emit-continuation octets code 0))
      (4
       (vector-push-extend (+ #xF0 (ash code -18)) octets)
       (%lsp-utf8-emit-continuation octets code 12)
       (%lsp-utf8-emit-continuation octets code 6)
       (%lsp-utf8-emit-continuation octets code 0)))))

(defun %lsp-utf8-encode (string)
  (let ((octets (make-array 0 :element-type '(unsigned-byte 8)
                            :adjustable t :fill-pointer 0)))
    (loop for character across string
          do (%lsp-utf8-emit-codepoint octets (char-code character)))
    octets))

(defun %lsp-utf8-sequence (octets index)
  (let* ((first (aref octets index))
         (width (cond
                  ((<= first #x7F) 1)
                  ((<= #xC2 first #xDF) 2)
                  ((<= #xE0 first #xEF) 3)
                  ((<= #xF0 first #xF4) 4)
                  (t (error "Invalid UTF-8 leading byte: ~X" first))))
         (code (logand first
                       (case width
                         (1 #x7F) (2 #x1F) (3 #x0F) (4 #x07)))))
    (when (> (+ index width) (length octets))
      (error "Truncated UTF-8 sequence"))
    (loop for offset from 1 below width
          for byte = (aref octets (+ index offset))
          do (unless (<= #x80 byte #xBF)
               (error "Invalid UTF-8 continuation byte: ~X" byte))
             (setf code (+ (ash code 6) (logand byte #x3F))))
    (when (or (and (= width 3) (< code #x800))
              (and (= width 4) (< code #x10000))
              (<= #xD800 code #xDFFF)
              (> code #x10FFFF))
      (error "Invalid UTF-8 code point: ~X" code))
    (values code (+ index width))))

(defun %lsp-utf8-decode (octets)
  (with-output-to-string (output)
    (loop with index = 0
          while (< index (length octets))
          do (multiple-value-bind (code next-index)
                 (%lsp-utf8-sequence octets index)
               (write-char (code-char code) output)
               (setf index next-index)))))

(defun %lsp-header-octets (string)
  (let ((octets (make-array (length string)
                            :element-type '(unsigned-byte 8))))
    (loop for character across string
          for index from 0
          for code = (char-code character)
          do (unless (<= code #x7F)
               (error "LSP header is not ASCII: ~S" string))
             (setf (aref octets index) code))
    octets))

(defun %lsp-find-header-end (octets)
  (loop for index from 0 below (- (length octets) 3)
        when (and (= (aref octets index) 13)
                  (= (aref octets (+ index 1)) 10)
                  (= (aref octets (+ index 2)) 13)
                  (= (aref octets (+ index 3)) 10))
          do (return index)))

(defun %lsp-header-string (octets)
  (with-output-to-string (output)
    (loop for octet across octets do (write-char (code-char octet) output))))

(defun %lsp-header-line-fields (line)
  (let ((colon (position #\: line)))
    (unless colon
      (error "Invalid LSP header line: ~S" line))
    (values (string-trim '(#\Space #\Tab) (subseq line 0 colon))
            (string-trim '(#\Space #\Tab #\Return)
                         (subseq line (1+ colon))))))

(defun %lsp-content-length-value (value)
  (handler-case
      (parse-integer value :junk-allowed nil)
    (error ()
      (error "Invalid Content-Length: ~S" value))))

(defun %lsp-content-length (header)
  (let ((length-value nil))
    (loop with start = 0
          for end = (or (position #\Newline header :start start)
                        (length header))
          for line = (string-trim '(#\Space #\Tab #\Return)
                                  (subseq header start end))
          do (when (plusp (length line))
               (multiple-value-bind (name value)
                   (%lsp-header-line-fields line)
                 (when (string-equal name "Content-Length")
                   (when length-value
                     (error "Duplicate Content-Length header"))
                   (setf length-value (%lsp-content-length-value value)))))
             (if (= end (length header))
                 (return length-value)
                 (setf start (1+ end))))))
