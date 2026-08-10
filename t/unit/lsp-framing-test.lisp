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

(describe
  "LSP framing"
  (it "frames and decodes UTF-8 JSON"
    (let* ((json "{\"jsonrpc\":\"2.0\",\"result\":\"日本語\"}")
           (frame (loom/feature/lsp::loom-lsp-frame-encode json)))
      (multiple-value-bind (decoded consumed status)
          (loom/feature/lsp::loom-lsp-frame-decode frame)
        (expect status :to-be :complete)
        (expect decoded :to-equal json)
        (expect consumed :to-equal (length frame))))
    (let* ((json "{\"ok\":true}")
           (frame (loom/feature/lsp::loom-lsp-frame-encode json))
           (partial (subseq frame 0 (floor (length frame) 2))))
      (multiple-value-bind (decoded consumed status)
          (loom/feature/lsp::loom-lsp-frame-decode partial)
        (expect decoded :to-be nil)
        (expect consumed :to-equal 0)
        (expect status :to-be :incomplete)))
    (multiple-value-bind (decoded consumed status)
        (loom/feature/lsp::loom-lsp-frame-decode #())
      (expect decoded :to-be nil)
      (expect consumed :to-equal 0)
      (expect status :to-be :incomplete)))

  (it "rejects malformed headers and invalid UTF-8"
    (let* ((accent (string (code-char #xE9)))
           (encoded (loom/feature/lsp::%lsp-utf8-encode accent)))
      (expect (coerce encoded 'list) :to-equal '(#xC3 #xA9))
      (expect (loom/feature/lsp::%lsp-utf8-decode encoded)
              :to-equal
              accent))
    (let* ((emoji (string (code-char #x1F642)))
           (encoded (loom/feature/lsp::%lsp-utf8-encode emoji)))
      (expect (length encoded) :to-equal 4)
      (expect (loom/feature/lsp::%lsp-utf8-decode encoded)
              :to-equal
              emoji))
    (signals type-error
      (loom/feature/lsp::loom-lsp-frame-encode 42))
    (signals error
      (loom/feature/lsp::%lsp-utf8-decode (%lsp-octets #x80)))
    (signals error
      (loom/feature/lsp::%lsp-utf8-decode (%lsp-octets #xE2 #x82)))
    (signals error
      (loom/feature/lsp::%lsp-utf8-decode (%lsp-octets #xE2 #x28 #xA1)))
    (signals error
      (loom/feature/lsp::%lsp-utf8-decode (%lsp-octets #xE0 #x80 #x80)))
    (signals error
      (loom/feature/lsp::%lsp-utf8-decode (%lsp-octets #xED #xA0 #x80)))
    (signals error
      (loom/feature/lsp::%lsp-utf8-decode
       (%lsp-octets #xF4 #x90 #x80 #x80)))
    (let ((surrogate (code-char #xD800)))
      (when surrogate
        (signals error
          (loom/feature/lsp::%lsp-utf8-encode (string surrogate)))))
    (let ((crlf (%lsp-crlf)))
      (signals error
        (loom/feature/lsp::%lsp-header-octets
         (format nil "Content-Léngth: 0~A~A" crlf crlf)))
      (signals error
        (loom/feature/lsp::loom-lsp-frame-decode
         (%lsp-raw-frame (format nil "Content-Length 0~A~A" crlf crlf)
                         #())))
      (signals error
        (loom/feature/lsp::loom-lsp-frame-decode
         (%lsp-raw-frame
          (format nil "Content-Length: 0~AContent-Length: 0~A~A"
                  crlf crlf crlf)
          #())))
      (signals error
        (loom/feature/lsp::loom-lsp-frame-decode
         (%lsp-raw-frame (format nil "Content-Length: nope~A~A" crlf crlf)
                         #())))
      (multiple-value-bind (decoded consumed status)
          (loom/feature/lsp::loom-lsp-frame-decode
           (%lsp-raw-frame
            (format nil "X-Test: 1~AContent-Length: 0~A~A"
                    crlf crlf crlf)
            #()))
        (expect decoded :to-equal "")
        (expect consumed
                :to-equal
                (length (%lsp-raw-octets
                         (format nil "X-Test: 1~AContent-Length: 0~A~A"
                                 crlf crlf crlf))))
        (expect status :to-be :complete))
      (signals error
        (loom/feature/lsp::loom-lsp-frame-decode
         (%lsp-raw-frame (format nil "X-Test: 1~A~A" crlf crlf)
                         #())))
      (multiple-value-bind (decoded consumed status)
          (loom/feature/lsp::loom-lsp-frame-decode
           (%lsp-raw-frame (format nil "Content-Length: 3~A~A" crlf crlf)
                           (%lsp-octets 1 2)))
        (expect decoded :to-be nil)
        (expect consumed :to-equal 0)
        (expect status :to-be :incomplete))
      (multiple-value-bind (decoded consumed status)
          (loom/feature/lsp::loom-lsp-frame-decode
           (%lsp-raw-frame (format nil "Content-Length: 0~A~A" crlf crlf)
                           #()))
        (expect decoded :to-equal "")
        (expect consumed
                :to-equal
                (length (%lsp-raw-octets
                         (format nil "Content-Length: 0~A~A" crlf crlf))))
        (expect status :to-be :complete)))))

(describe
  "LSP domain values"
  (it
    "preserves nested positions, diagnostics, and documents"
    (let* ((start (make-lsp-position 1 2))
           (end (make-lsp-position 1 5))
           (range (make-lsp-range start end))
           (diagnostic
             (make-lsp-diagnostic range "unused variable"
                                   :severity 2
                                   :source "compiler"
                                   :code 42))
           (document
             (make-lsp-document "file:///main.lisp" "commonlisp" 3
                                "(+ 1 2)")))
      (expect (list (lsp-position-line start)
                    (lsp-position-character start)
                    (lsp-position-line end)
                    (lsp-position-character end))
              :to-equal
              '(1 2 1 5))
      (expect (list (lsp-range-start range)
                    (lsp-range-end range)
                    (lsp-diagnostic-message diagnostic)
                    (lsp-diagnostic-severity diagnostic)
                    (lsp-diagnostic-source diagnostic)
                    (lsp-diagnostic-code diagnostic))
              :to-equal
              (list start end "unused variable" 2 "compiler" 42))
      (expect (list (lsp-document-uri document)
                    (lsp-document-language-id document)
                    (lsp-document-version document)
                    (lsp-document-text document))
              :to-equal
              '("file:///main.lisp" "commonlisp" 3 "(+ 1 2)"))))

  (it-each
      ((1 "error") (2 "warning") (3 "info") (4 "hint") (nil "info")
       (99 "info"))
      "maps severity ~A to ~A"
      (severity expected)
    (expect (lsp-diagnostic-severity-name severity) :to-equal expected)))
