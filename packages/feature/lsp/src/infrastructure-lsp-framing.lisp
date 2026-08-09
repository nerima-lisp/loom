;;;; packages/feature/lsp/src/infrastructure-lsp-framing.lisp
;;;;
;;;; Pure UTF-8 and Content-Length framing for the LSP transport boundary.
;;;; It has no process or thread state; the process adapter consumes these
;;;; frames at the infrastructure boundary.
(in-package #:loom/feature/lsp)

(defun %lsp-utf8-encode (string)
  (let ((octets (make-array 0 :element-type '(unsigned-byte 8)
                            :adjustable t :fill-pointer 0)))
    (flet ((emit (octet) (vector-push-extend octet octets)))
      (loop for character across string
            for code = (char-code character)
            do (cond
                 ((<= code #x7F)
                  (emit code))
                 ((<= code #x7FF)
                  (emit (+ #xC0 (ash code -6)))
                  (emit (+ #x80 (logand code #x3F))))
                 ((<= code #xFFFF)
                  (when (<= #xD800 code #xDFFF)
                    (error "Cannot encode a UTF-8 surrogate code point: ~S"
                           code))
                  (emit (+ #xE0 (ash code -12)))
                  (emit (+ #x80 (logand (ash code -6) #x3F)))
                  (emit (+ #x80 (logand code #x3F))))
                 ((<= code #x10FFFF)
                  (emit (+ #xF0 (ash code -18)))
                  (emit (+ #x80 (logand (ash code -12) #x3F)))
                  (emit (+ #x80 (logand (ash code -6) #x3F)))
                  (emit (+ #x80 (logand code #x3F)))))))
    octets))

(defun %lsp-utf8-decode (octets)
  (with-output-to-string (output)
    (loop with index = 0
          while (< index (length octets))
          do (let* ((first (aref octets index))
                    (width (cond
                             ((<= first #x7F) 1)
                             ((<= #xC2 first #xDF) 2)
                             ((<= #xE0 first #xEF) 3)
                             ((<= #xF0 first #xF4) 4)
                             (t (error "Invalid UTF-8 leading byte: ~X" first))))
                    (code (logand first
                                  (case width
                                    (1 #x7F)
                                    (2 #x1F)
                                    (3 #x0F)
                                    (4 #x07)))))
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
               (write-char (code-char code) output)
               (incf index width)))))

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

(defun %lsp-content-length (header)
  (let ((length-value nil))
    (loop with start = 0
          for end = (or (position #\Newline header :start start)
                        (length header))
          for line = (string-trim '(#\Space #\Tab #\Return)
                                  (subseq header start end))
          do (when (plusp (length line))
               (let ((colon (position #\: line)))
                 (unless colon
                   (error "Invalid LSP header line: ~S" line))
                 (let ((name (string-trim '(#\Space #\Tab)
                                          (subseq line 0 colon)))
                       (value (string-trim '(#\Space #\Tab #\Return)
                                           (subseq line (1+ colon)))))
                   (when (string-equal name "Content-Length")
                     (when length-value
                       (error "Duplicate Content-Length header"))
                     (setf length-value
                           (handler-case
                               (parse-integer value :junk-allowed nil)
                             (error ()
                               (error "Invalid Content-Length: ~S" value))))))))
             (if (= end (length header))
                 (return length-value)
                 (setf start (1+ end))))))

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

(defun loom-lsp-frame-decode (octets)
  "Decode the first LSP frame in OCTETS.

Returns three values: the JSON string, the number of consumed octets, and one
of :COMPLETE or :INCOMPLETE.  Malformed headers and invalid UTF-8 signal an
error; an incomplete frame is a normal result for a streaming reader."
  (check-type octets vector)
  (let ((header-end (%lsp-find-header-end octets)))
    (unless header-end
      (return-from loom-lsp-frame-decode (values nil 0 :incomplete)))
    (let* ((header (%lsp-header-string (subseq octets 0 header-end)))
           (body-length (%lsp-content-length header)))
      (unless body-length
        (error "LSP frame has no Content-Length header"))
      (let* ((body-start (+ header-end 4))
             (body-end (+ body-start body-length)))
        (when (> body-end (length octets))
          (return-from loom-lsp-frame-decode
            (values nil 0 :incomplete)))
        (values (%lsp-utf8-decode (subseq octets body-start body-end))
                body-end
                :complete)))))
