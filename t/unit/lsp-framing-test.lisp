(in-package #:loom/test)

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
