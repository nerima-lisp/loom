(in-package #:loom/test)

(describe "file format codecs"
          (it
           "round-trips mixed line endings without changing their byte layout"
           (let ((octets #(65 13 10 66 10 67 13 10)))
             (multiple-value-bind (text format)
                 (loom/feature/files::%decode-file-octets octets)
               (expect (loom/feature/files::%encode-file-text text format)
                       :to-equalp
                       octets))))
          (it "preserves mixed line endings after a character edit"
              (let ((octets #(65 13 10 66 10 67 13 10)))
                (multiple-value-bind (text format)
                    (loom/feature/files::%decode-file-octets octets)
                  (let ((edited-text
                         (format nil "~A!~A" (subseq text 0 1) (subseq text 1))))
                    (expect
                     (loom/feature/files::%encode-file-text edited-text format)
                     :to-equalp
                     #(65 33 13 10 66 10 67 13 10))))))
          (it "uses the dominant newline style for added line endings"
              (let ((octets #(65 13 10 66 10 67 13 10)))
                (multiple-value-bind (text format)
                    (loom/feature/files::%decode-file-octets octets)
                  (let ((edited-text
                         (format nil "~AD~A" text (string (code-char 10)))))
                    (expect
                     (loom/feature/files::%encode-file-text edited-text format)
                     :to-equalp
                     #(65 13 10 66 10 67 13 10 68 13 10))))))
          (it "keeps line terminators through a leading insertion and later line edits"
              (let ((octets
                     #(65 13 10 98 101 116 97 10
                       103 97 109 109 97 13 10
                       100 101 108 116 97 10
                       69 13 10)))
                (multiple-value-bind (text format)
                    (loom/feature/files::%decode-file-octets octets)
                  (let ((edited-text
                         (format nil "~C~A~C~A!~C~A~C~A~C~A!~C"
                                 (code-char 10)
                                 "A"
                                 (code-char 10)
                                 "beta"
                                 (code-char 10)
                                 "gamma"
                                 (code-char 10)
                                 "delta"
                                 (code-char 10)
                                 "E"
                                 (code-char 10))))
                    (expect
                     (loom/feature/files::%encode-file-text edited-text format)
                     :to-equalp
                     #(13 10 65 13 10
                       98 101 116 97 33 10
                       103 97 109 109 97 13 10
                       100 101 108 116 97 10
                       69 33 13 10))))))
          (it "keeps the original terminator on the suffix when splitting a line"
              (let ((octets #(65 13 10 98 101 116 97 10 103 97 109 109 97 13 10)))
                (multiple-value-bind (text format)
                    (loom/feature/files::%decode-file-octets octets)
                  (declare (ignore text))
                  (let ((edited-text
                         (format nil "A~Cbe~Cta~Cgamma~C"
                                 (code-char 10)
                                 (code-char 10)
                                 (code-char 10)
                                 (code-char 10))))
                    (expect
                     (loom/feature/files::%encode-file-text edited-text format)
                     :to-equalp
                     #(65 13 10 98 101 13 10 116 97 10
                       103 97 109 109 97 13 10))))))
          (it "preserves existing anchors when appending a duplicate line"
              (let ((octets #(65 13 10 88 10 66)))
                (multiple-value-bind (text format)
                    (loom/feature/files::%decode-file-octets octets)
                  (let ((edited-text (format nil "~A~CX" text (code-char 10))))
                    (expect
                     (loom/feature/files::%encode-file-text edited-text format)
                     :to-equalp
                     #(65 13 10 88 10 66 13 10 88))))))
          (it "preserves an internal blank line when appending a terminator"
              (let ((octets #(65 13 10 10 66)))
                (multiple-value-bind (text format)
                    (loom/feature/files::%decode-file-octets octets)
                  (let ((edited-text (format nil "~A~C" text (code-char 10))))
                    (expect
                     (loom/feature/files::%encode-file-text edited-text format)
                     :to-equalp
                     #(65 13 10 10 66 13 10))))))
          (it "keeps repeated line terminators when inserting between duplicates"
              (let ((octets #(88 13 10 65 10 65 13 10 89 13 10)))
                (multiple-value-bind (text format)
                    (loom/feature/files::%decode-file-octets octets)
                  (declare (ignore text))
                  (let ((edited-text
                         (format nil "X~CA~CZ~CA~CY~C"
                                 (code-char 10)
                                 (code-char 10)
                                 (code-char 10)
                                 (code-char 10)
                                 (code-char 10))))
                    (expect
                     (loom/feature/files::%encode-file-text edited-text format)
                     :to-equalp
                     #(88 13 10 65 10 90 13 10 65 13 10 89 13 10))))))
          (it "keeps repeated line terminators when deleting between duplicates"
              (let ((octets #(88 13 10 65 10 90 13 10 65 13 10 89 13 10)))
                (multiple-value-bind (text format)
                    (loom/feature/files::%decode-file-octets octets)
                  (declare (ignore text))
                  (let ((edited-text
                         (format nil "X~CA~CA~CY~C"
                                 (code-char 10)
                                 (code-char 10)
                                 (code-char 10)
                                 (code-char 10))))
                    (expect
                     (loom/feature/files::%encode-file-text edited-text format)
                     :to-equalp
                     #(88 13 10 65 10 65 13 10 89 13 10))))))
          (it "keeps ordered anchors when prepending a duplicate line"
              (let ((octets #(65 13 10 66 10)))
                (multiple-value-bind (text format)
                    (loom/feature/files::%decode-file-octets octets)
                  (declare (ignore text))
                  (let ((edited-text
                         (format nil "B~CA~CB~C"
                                 (code-char 10)
                                 (code-char 10)
                                 (code-char 10))))
                    (expect
                     (loom/feature/files::%encode-file-text edited-text format)
                     :to-equalp
                     #(66 13 10 65 13 10 66 10)))))))

(describe "file buffer construction"
  (it "creates a buffer with the requested metadata"
    (let* ((path #P"startup-note.lisp")
           (buffer (loom/feature/files:make-file-buffer
                    path
                    :name "startup-note.lisp"
                    :initial-content "draft")))
      (expect (loom/core/buffer:buffer-path buffer) :to-equal path)
      (expect (loom/core/buffer:buffer-name buffer)
              :to-equal
              "startup-note.lisp")
      (expect (loom/core/buffer:buffer-text buffer) :to-equal "draft"))))
(describe "file format scan edge cases"
  (it "keeps bare carriage returns as text"
    (let ((octets #(65 13 66 13 67)))
      (multiple-value-bind (text format)
          (loom/feature/files::%decode-file-octets octets)
        (expect text :to-equal (format nil "A~CB~CC" #\Return #\Return))
        (expect (loom/feature/files::%file-format-newline format) :to-equal :lf)
        (expect (loom/feature/files::%file-format-newline-sequence format)
                :to-equalp
                #())
        (expect (loom/feature/files::%encode-file-text text format)
                :to-equalp
                octets))))
  (it "preserves BOM-prefixed Latin-1 bytes and mixed newline styles"
    (let ((octets #(239 187 191 65 13 10 233 13 88 10)))
      (multiple-value-bind (text format)
          (loom/feature/files::%decode-file-octets octets)
        (expect text
                :to-equal
                (format nil "A~C~C~CX~C"
                        #\Linefeed
                        (code-char #xe9)
                        #\Return
                        #\Linefeed))
        (expect (loom/feature/files::%file-format-encoding format)
                :to-equal
                :latin-1)
        (expect (loom/feature/files::%file-format-bom-p format) :to-be-truthy)
        (expect (loom/feature/files::%file-format-newline format)
                :to-equal
                :crlf)
        (expect (loom/feature/files::%file-format-mixed-newlines-p format)
                :to-be-truthy)
        (expect (loom/feature/files::%file-format-newline-sequence format)
                :to-equalp
                #(:crlf :lf))
        (expect (loom/feature/files::%encode-file-text text format)
                :to-equalp
                octets))))
  (it "reads file bytes into the result vector"
  (let* ((path
           (merge-pathnames
            (make-pathname :name (symbol-name (gensym "loom-file-read-"))
                           :type "bytes")
            (uiop:temporary-directory)))
         (octets #(239 187 191 65 13 10 233 13 88 10)))
    (unwind-protect
         (progn
           (with-open-file (stream path
                                   :direction :output
                                   :element-type '(unsigned-byte 8)
                                   :if-exists :error
                                   :if-does-not-exist :create)
             (write-sequence octets stream))
           (expect (loom/feature/files::%native-read-file-octets path)
                   :to-equalp
                   octets))
      (when (probe-file path)
        (delete-file path)))))
    (it "returns an exact-sized newline sequence"
    (let* ((count 100000)
           (octets (make-array count
                               :element-type '(unsigned-byte 8)
                               :initial-element 10)))
      (multiple-value-bind (text format)
          (loom/feature/files::%decode-file-octets octets)
        (declare (ignore text))
        (let ((sequence
               (loom/feature/files::%file-format-newline-sequence format)))
          (expect (length sequence) :to-equal count)
          (expect (array-total-size sequence) :to-equal count))))))
