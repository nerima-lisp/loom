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
