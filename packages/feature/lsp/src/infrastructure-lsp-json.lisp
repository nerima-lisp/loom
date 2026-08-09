;;;; packages/feature/lsp/src/infrastructure-lsp-json.lisp
;;;;
;;;; A deliberately small, strict JSON value codec used by the LSP adapter.
;;;; Loom does not otherwise depend on a JSON library, and keeping this codec
;;;; here makes the application layer independent of both JSON syntax and
;;;; process I/O.  Objects and arrays use explicit structs so JSON null, an
;;;; empty array, and an empty object never become ambiguous with NIL.
(in-package #:loom)

(defparameter +loom-json-null+
  (gensym "JSON-NULL-")
  "The JSON null value in LOOM's internal JSON representation.")

(defstruct (loom-json-object
            (:constructor make-loom-json-object (entries)))
  "A JSON object represented by an alist of string keys and values."
  entries)

(defstruct (loom-json-array
            (:constructor make-loom-json-array (elements)))
  "A JSON array represented by an ordered list of values."
  elements)

(defun loom-json-object-get (object key &optional default)
  "Return OBJECT's KEY value and a presence flag.

KEY is compared as a JSON string, and DEFAULT is returned when KEY is absent.
The second value distinguishes an absent key from a present JSON null value."
  (check-type object loom-json-object)
  (check-type key string)
  (let ((entry (assoc key (loom-json-object-entries object) :test #'string=)))
    (if entry
        (values (cdr entry) t)
        (values default nil))))

(defun %loom-json-error (source index format-control &rest arguments)
  (error "Invalid JSON at character ~D: ~? (source: ~S)"
         index format-control arguments source))

(defstruct (loom-json-parser
            (:constructor %make-loom-json-parser (source)))
  source
  (index 0 :type fixnum))

(defun %json-length (parser)
  (length (loom-json-parser-source parser)))

(defun %json-at-end-p (parser)
  (>= (loom-json-parser-index parser) (%json-length parser)))

(defun %json-peek (parser)
  (unless (%json-at-end-p parser)
    (char (loom-json-parser-source parser)
          (loom-json-parser-index parser))))

(defun %json-take (parser)
  (let ((character (%json-peek parser)))
    (when character
      (incf (loom-json-parser-index parser)))
    character))

(defun %json-expect (parser expected)
  (unless (eql (%json-take parser) expected)
    (%loom-json-error (loom-json-parser-source parser)
                      (loom-json-parser-index parser)
                      "expected ~S"
                      expected)))

(defun %json-skip-whitespace (parser)
  (loop while (and (not (%json-at-end-p parser))
                   (find (%json-peek parser) " ~T~N~R" :test #'char=))
        do (%json-take parser)))

(defun %json-hex-value (character)
  (digit-char-p character 16))

(defun %json-read-hex-quad (parser)
  (let ((value 0))
    (loop repeat 4
          do (let ((digit (%json-hex-value (%json-take parser))))
               (unless digit
                 (%loom-json-error (loom-json-parser-source parser)
                                   (loom-json-parser-index parser)
                                   "expected four hexadecimal digits"))
               (setf value (+ (* value 16) digit)))
          finally (return value))))

(defun %json-string-character (parser)
  (let ((character (%json-take parser)))
    (unless character
      (%loom-json-error (loom-json-parser-source parser)
                        (loom-json-parser-index parser)
                        "unterminated string"))
    (if (char= character #\\)
        (case (%json-take parser)
          (#\" #\")
          (#\\ #\\)
          (#\/ #\/)
          (#\b #\Backspace)
          (#\f #\Page)
          (#\n #\Newline)
          (#\r #\Return)
          (#\t #\Tab)
          (#\u
           (let ((code (%json-read-hex-quad parser)))
             (cond
               ((<= #xD800 code #xDBFF)
                (unless (and (eql (%json-take parser) #\\)
                             (eql (%json-take parser) #\u))
                  (%loom-json-error (loom-json-parser-source parser)
                                    (loom-json-parser-index parser)
                                    "a high surrogate must be followed by a low surrogate"))
                (let ((low (%json-read-hex-quad parser)))
                  (unless (<= #xDC00 low #xDFFF)
                    (%loom-json-error (loom-json-parser-source parser)
                                      (loom-json-parser-index parser)
                                      "invalid low surrogate"))
                  (or (code-char (+ #x10000
                                    (* (- code #xD800) #x400)
                                    (- low #xDC00)))
                      (%loom-json-error (loom-json-parser-source parser)
                                        (loom-json-parser-index parser)
                                        "invalid Unicode code point"))))
               ((<= #xDC00 code #xDFFF)
                (%loom-json-error (loom-json-parser-source parser)
                                  (loom-json-parser-index parser)
                                  "a low surrogate cannot appear alone"))
               (t
                (or (code-char code)
                    (%loom-json-error (loom-json-parser-source parser)
                                      (loom-json-parser-index parser)
                                      "invalid Unicode code point"))))))
          (otherwise
           (%loom-json-error (loom-json-parser-source parser)
                             (loom-json-parser-index parser)
                             "unknown string escape ~S"
                             character)))
        (if (< (char-code character) #x20)
            (%loom-json-error (loom-json-parser-source parser)
                              (loom-json-parser-index parser)
                              "control character in string")
            character))))

(defun %json-parse-string (parser)
  (%json-expect parser #\")
  (with-output-to-string (output)
    (loop
      (if (eql (%json-peek parser) #\")
          (progn
            (%json-take parser)
            (return))
          (write-char (%json-string-character parser) output)))))

(defun %json-number-character-p (character)
  (and character
       (or (digit-char-p character 10)
           (find character "+-.eE" :test #'char=))))

(defun %json-parse-number (parser)
  (let* ((source (loom-json-parser-source parser))
         (start (loom-json-parser-index parser)))
    (loop while (%json-number-character-p (%json-peek parser))
          do (%json-take parser))
    (let ((token (subseq source start (loom-json-parser-index parser))))
      (unless (and (plusp (length token))
                   (handler-case
                       (progn
                         (let ((position 0))
                           (when (char= (char token position) #\-)
                             (incf position))
                           (unless (and (< position (length token))
                                        (digit-char-p (char token position) 10))
                             (return-from %json-parse-number
                               (%loom-json-error source start "invalid number")))
                           (when (char= (char token position) #\0)
                             (incf position)
                             (when (and (< position (length token))
                                        (digit-char-p (char token position) 10))
                               (return-from %json-parse-number
                                 (%loom-json-error source start "leading zero in number"))))
                           (loop while (and (< position (length token))
                                            (digit-char-p (char token position) 10))
                                 do (incf position))
                           (when (and (< position (length token))
                                      (char= (char token position) #\.))
                             (incf position)
                             (unless (and (< position (length token))
                                          (digit-char-p (char token position) 10))
                               (return-from %json-parse-number
                                 (%loom-json-error source start "fraction needs digits")))
                             (loop while (and (< position (length token))
                                              (digit-char-p (char token position) 10))
                                   do (incf position)))
                           (when (and (< position (length token))
                                      (find (char token position) "eE" :test #'char=))
                             (incf position)
                             (when (and (< position (length token))
                                        (find (char token position) "+-" :test #'char=))
                               (incf position))
                             (unless (and (< position (length token))
                                          (digit-char-p (char token position) 10))
                               (return-from %json-parse-number
                                 (%loom-json-error source start "exponent needs digits")))
                             (loop while (and (< position (length token))
                                              (digit-char-p (char token position) 10))
                                   do (incf position)))
                           (unless (= position (length token))
                             (return-from %json-parse-number
                               (%loom-json-error source start "invalid number")))
                           position))
                     (error () nil)))
        (%loom-json-error source start "invalid number"))
      (if (find-if (lambda (character)
                     (find character ".eE" :test #'char=))
                   token)
          (let ((*read-eval* nil)
                (*read-default-float-format* 'double-float))
            (handler-case
                (multiple-value-bind (number position)
                    (read-from-string token nil nil)
                  (unless (= position (length token))
                    (%loom-json-error source start "invalid number"))
                  number)
              (error ()
                (%loom-json-error source start "invalid number"))))
          (parse-integer token)))))

(defun %json-parse-literal (parser literal value)
  (dolist (expected (coerce literal 'list) value)
    (unless (eql (%json-take parser) expected)
      (%loom-json-error (loom-json-parser-source parser)
                        (loom-json-parser-index parser)
                        "invalid literal"))))

(declaim (ftype function %json-parse-value))

(defun %json-parse-array (parser)
  (%json-expect parser #\[)
  (%json-skip-whitespace parser)
  (let ((elements (list)))
    (unless (eql (%json-peek parser) #\])
      (loop
        (push (%json-parse-value parser) elements)
        (%json-skip-whitespace parser)
        (cond
          ((eql (%json-peek parser) #\])
           (return))
          ((eql (%json-peek parser) #\,)
           (%json-take parser)
           (%json-skip-whitespace parser))
          (t
           (%loom-json-error (loom-json-parser-source parser)
                             (loom-json-parser-index parser)
                             "expected comma or closing array bracket")))))
    (%json-expect parser #\])
    (make-loom-json-array (nreverse elements))))

(defun %json-parse-object (parser)
  (%json-expect parser #\{)
  (%json-skip-whitespace parser)
  (let ((entries (list)))
    (unless (eql (%json-peek parser) #\})
      (loop
        (unless (eql (%json-peek parser) #\")
          (%loom-json-error (loom-json-parser-source parser)
                            (loom-json-parser-index parser)
                            "object keys must be strings"))
        (let ((key (%json-parse-string parser)))
          (%json-skip-whitespace parser)
          (%json-expect parser #\:)
          (%json-skip-whitespace parser)
          (when (assoc key entries :test #'string=)
            (%loom-json-error (loom-json-parser-source parser)
                              (loom-json-parser-index parser)
                              "duplicate object key ~S"
                              key))
          (push (cons key (%json-parse-value parser)) entries))
        (%json-skip-whitespace parser)
        (cond
          ((eql (%json-peek parser) #\})
           (return))
          ((eql (%json-peek parser) #\,)
           (%json-take parser)
           (%json-skip-whitespace parser))
          (t
           (%loom-json-error (loom-json-parser-source parser)
                             (loom-json-parser-index parser)
                             "expected comma or closing object brace")))))
    (%json-expect parser #\})
    (make-loom-json-object (nreverse entries))))

(defun %json-parse-value (parser)
  (%json-skip-whitespace parser)
  (case (%json-peek parser)
    (#\" (%json-parse-string parser))
    (#\{ (%json-parse-object parser))
    (#\[ (%json-parse-array parser))
    (#\t (%json-parse-literal parser "true" t))
    (#\f (%json-parse-literal parser "false" nil))
    (#\n (%json-parse-literal parser "null" +loom-json-null+))
    ((#\- #\0 #\1 #\2 #\3 #\4 #\5 #\6 #\7 #\8 #\9)
     (%json-parse-number parser))
    (otherwise
     (%loom-json-error (loom-json-parser-source parser)
                       (loom-json-parser-index parser)
                       "expected a JSON value"))))

(defun loom-json-parse (source)
  "Parse SOURCE into Loom's strict JSON representation."
  (check-type source string)
  (let ((parser (%make-loom-json-parser source)))
    (%json-skip-whitespace parser)
    (let ((value (%json-parse-value parser)))
      (%json-skip-whitespace parser)
      (unless (%json-at-end-p parser)
        (%loom-json-error source (loom-json-parser-index parser)
                          "trailing data"))
      value)))

(defun %json-append (output string)
  (write-string string output))

(defun %json-encode-string (string output)
  (write-char #\" output)
  (loop for character across string
        for code = (char-code character)
        do (case character
             (#\" (%json-append output "\\\""))
             (#\\ (%json-append output "\\\\"))
             (#\Backspace (%json-append output "\\b"))
             (#\Page (%json-append output "\\f"))
             (#\Newline (%json-append output "\\n"))
             (#\Return (%json-append output "\\r"))
             (#\Tab (%json-append output "\\t"))
             (otherwise
              (if (< code #x20)
                  (format output "\\u~4,'0X" code)
                  (write-char character output)))))
  (write-char #\" output))

(defun %json-encode-number (number output)
  (cond
    ((integerp number) (format output "~D" number))
    ((floatp number)
     (when (or (not (= number number))
               (ignore-errors (sb-ext:float-infinity-p number)))
       (error "Cannot encode a non-finite JSON number: ~S" number))
     (let ((text (string-downcase (princ-to-string number))))
       (write-string (substitute #\e #\d text) output)))
    (t
     (error "Cannot encode JSON value as a number: ~S" number))))

(declaim (ftype function %json-encode-value))

(defun %json-encode-value (value output)
  (cond
    ((eq value +loom-json-null+) (%json-append output "null"))
    ((stringp value) (%json-encode-string value output))
    ((eq value t) (%json-append output "true"))
    ((null value) (%json-append output "false"))
    ((numberp value) (%json-encode-number value output))
    ((loom-json-object-p value)
     (write-char #\{ output)
     (loop for entries on (loom-json-object-entries value)
           for entry = (first entries)
           do (%json-encode-string (car entry) output)
              (write-char #\: output)
              (%json-encode-value (cdr entry) output)
              (when (rest entries) (write-char #\, output)))
     (write-char #\} output))
    ((loom-json-array-p value)
     (write-char #\[ output)
     (loop for elements on (loom-json-array-elements value)
           for element = (first elements)
           do (%json-encode-value element output)
              (when (rest elements) (write-char #\, output)))
     (write-char #\] output))
    (t
     (error "Cannot encode value as JSON: ~S" value))))

(defun loom-json-encode (value)
  "Encode a Loom JSON value as a UTF-8-ready Common Lisp string."
  (with-output-to-string (output)
    (%json-encode-value value output)))
