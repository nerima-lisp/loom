;;;; packages/feature/lsp/src/infrastructure-lsp-headers.lisp
;;;;
;;;; ASCII header parsing for the LSP framing boundary.
(in-package #:loom/feature/lsp)

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
                  (= (aref octets (1+ index)) 10)
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

(defun %lsp-header-lines (header)
  (loop with start = 0
        while (< start (length header))
        for end = (or (position #\Newline header :start start)
                      (length header))
        for line = (string-trim '(#\Space #\Tab #\Return)
                                (subseq header start end))
        do (setf start (if (= end (length header))
                           end
                           (1+ end)))
        when (plusp (length line))
          collect line))

(defun %lsp-content-length-line (line length-value found-p)
  (multiple-value-bind (name value)
      (%lsp-header-line-fields line)
    (if (string-equal name "Content-Length")
        (progn
          (when found-p
            (error "Duplicate Content-Length header"))
          (values (%lsp-content-length-value value) t))
        (values length-value found-p))))

(defun %lsp-content-length (header)
  (let ((length-value nil)
        (found-p nil))
    (dolist (line (%lsp-header-lines header) length-value)
      (multiple-value-bind (next-length next-found-p)
          (%lsp-content-length-line line length-value found-p)
        (setf length-value next-length
              found-p next-found-p)))))
