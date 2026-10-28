(in-package #:loom/feature/files)

(progn
  (progn
    (defstruct
        (%file-format
         (:constructor %make-file-format
                       (&key encoding
                             newline
                             mixed-newlines-p
                             newline-sequence
                             bom-p
                             original-text)))
      encoding
      newline
      mixed-newlines-p
      newline-sequence
      bom-p
      original-text)
    (define-condition %invalid-file-utf-8
      (error)
      ()))
  (defun %utf-8-continuation-octet (octets index)
    (unless (< index (length octets))
      (error '%invalid-file-utf-8))
    (let ((octet (aref octets index)))
      (unless (<= #x80 octet #xbf)
        (error '%invalid-file-utf-8))
      octet))
  (defun %decode-utf-8-character (octets index)
    (let ((first (aref octets index)))
      (cond
        ((<= first #x7f) (values first 1))
        ((<= #xc2 first #xdf)
         (let ((second (%utf-8-continuation-octet octets (1+ index))))
           (values (+ (ash (logand first #x1f) 6) (logand second #x3f)) 2)))
        ((<= #xe0 first #xef)
         (let* ((second (%utf-8-continuation-octet octets (1+ index)))
                (third (%utf-8-continuation-octet octets (+ index 2))))
           (unless
               (cond
                 ((= first #xe0) (<= #xa0 second #xbf))
                 ((= first #xed) (<= #x80 second #x9f))
                 (t (<= #x80 second #xbf)))
             (error '%invalid-file-utf-8))
           (values
            (+ (ash (logand first #x0f) 12)
               (ash (logand second #x3f) 6)
               (logand third #x3f))
            3)))
        ((<= #xf0 first #xf4)
         (let* ((second (%utf-8-continuation-octet octets (1+ index)))
                (third (%utf-8-continuation-octet octets (+ index 2)))
                (fourth (%utf-8-continuation-octet octets (+ index 3))))
           (unless
               (cond
                 ((= first #xf0) (<= #x90 second #xbf))
                 ((= first #xf4) (<= #x80 second #x8f))
                 (t (<= #x80 second #xbf)))
             (error '%invalid-file-utf-8))
           (values
            (+ (ash (logand first #x07) 18)
               (ash (logand second #x3f) 12)
               (ash (logand third #x3f) 6)
               (logand fourth #x3f))
            4)))
        (t (error '%invalid-file-utf-8)))))
  (defun %decode-utf-8-octets (octets &optional (start 0))
    (with-output-to-string (output)
      (loop with index = start
            while (< index (length octets))
            do (multiple-value-bind (code width)
                   (%decode-utf-8-character octets index)
                 (let ((character (code-char code)))
                   (unless character
                     (error '%invalid-file-utf-8))
                   (write-char character output))
                 (incf index width))))
    )
  (defun %decode-latin-1-octets (octets &optional (start 0))
    (with-output-to-string (output)
      (loop for index from start below (length octets)
            for octet = (aref octets index)
            do (let ((character (code-char octet)))
                 (unless character
                   (error "Unsupported Latin-1 byte ~D" octet))
                 (write-char character output))))
    )
  (defun %normalize-file-newlines (text)
    (let ((crlf-count 0)
          (lf-count 0)
          (first-newline nil)
          (newline-sequence (make-array 0 :adjustable t :fill-pointer 0)))
      (let ((normalized-text
             (with-output-to-string (output)
               (loop with index = 0
                     while (< index (length text))
                     do (let ((character (char text index)))
                          (cond
                           ((and (char= character #\Return)
                                 (< (1+ index) (length text))
                                 (char= (char text (1+ index)) #\Linefeed))
                            (write-char #\Linefeed output)
                            (incf crlf-count)
                            (unless first-newline
                              (setf first-newline :crlf))
                            (vector-push-extend :crlf newline-sequence)
                            (incf index 2))
                           ((char= character #\Linefeed)
                            (write-char character output)
                            (incf lf-count)
                            (unless first-newline
                              (setf first-newline :lf))
                            (vector-push-extend :lf newline-sequence)
                            (incf index))
                           (t
                            (write-char character output)
                            (incf index))))))))
        (values normalized-text
                (cond
                 ((> crlf-count lf-count) :crlf)
                 ((> lf-count crlf-count) :lf)
                 ((eq first-newline :crlf) :crlf)
                 (t :lf))
                (and (plusp crlf-count) (plusp lf-count))
                (make-array (length newline-sequence) :initial-contents newline-sequence))))
    )
  (defun %decode-file-octets (octets)
    (let* ((bom-p
            (and (>= (length octets) 3)
                 (= (aref octets 0) #xef)
                 (= (aref octets 1) #xbb)
                 (= (aref octets 2) #xbf)))
           (start (if bom-p 3 0)))
      (multiple-value-bind (text encoding)
          (handler-case (values (%decode-utf-8-octets octets start) :utf-8)
            (%invalid-file-utf-8 ()
                                 (values (%decode-latin-1-octets octets start) :latin-1)))
        (multiple-value-bind (normalized-text newline mixed-newlines-p newline-sequence)
            (%normalize-file-newlines text)
          (values normalized-text
                  (%make-file-format :encoding encoding
                                     :newline newline
                                     :mixed-newlines-p mixed-newlines-p
                                     :newline-sequence newline-sequence
                                     :bom-p bom-p
                                     :original-text
                                     (copy-seq normalized-text)))))))
  (defun %file-format-indicator (format)
    (format nil
            "~A ~A~A"
            (if (%file-format-mixed-newlines-p format)
                "Mixed"
                (if (eq (%file-format-newline format) :crlf)
                    "CRLF"
                    "LF"))
            (ecase (%file-format-encoding format)
              (:utf-8 "UTF-8")
              (:latin-1 "Latin-1"))
            (if (%file-format-bom-p format)
                " BOM"
                "")))
  (defun %expand-file-newlines (text newline newline-sequence original-text)
    (let* ((original-text (or original-text ""))
           (original-lines (make-array 0 :adjustable t :fill-pointer 0))
           (new-lines (make-array 0 :adjustable t :fill-pointer 0))
           (old-line-counts (make-hash-table :test (function equal)))
           (old-line-positions (make-hash-table :test (function equal)))
           (new-line-counts (make-hash-table :test (function equal)))
           (candidates (make-array 0 :adjustable t :fill-pointer 0))
           (newline-styles
            (make-array (count #\Linefeed text) :initial-element newline))
           (matches nil))
      (labels
          ((collect-lines (source lines)
             (loop with start = 0
                   for newline-index = (position #\Linefeed source :start start)
                   do (if newline-index
                          (progn
                            (vector-push-extend
                             (subseq source start newline-index)
                             lines)
                            (setf start (1+ newline-index)))
                          (progn
                            (vector-push-extend (subseq source start) lines)
                            (return)))))
           (count-lines (lines counts positions)
             (loop for line across lines
                   for index from 0
                   do (incf (gethash line counts 0))
                      (when positions
                        (setf (gethash line positions) index))))
           (copy-run (old-start new-start old-count new-count)
             (let* ((count (min old-count new-count))
                    (old-offset (- old-count count))
                    (new-offset (- new-count count)))
               (loop for offset from 0 below count
                     for old-index = (+ old-start old-offset offset)
                     for new-index = (+ new-start new-offset offset)
                     when (and (< old-index (length newline-sequence))
                               (< new-index (length newline-styles)))
                       do (setf (aref newline-styles new-index)
                                (aref newline-sequence old-index)))))
           (map-run (old-start new-start old-count new-count)
             (let ((old-occurrences (make-hash-table :test (function equal)))
                   (new-ranks (make-hash-table :test (function equal)))
                   (candidates (make-array 0 :adjustable t :fill-pointer 0))
                   (matches nil))
               (loop for old-index from old-start
                     below (+ old-start old-count)
                     for line = (aref original-lines old-index)
                     do (let ((positions (gethash line old-occurrences)))
                          (unless positions
                            (setf positions (make-array 0 :adjustable t :fill-pointer 0)
                                  (gethash line old-occurrences) positions))
                          (vector-push-extend old-index positions)))
               (loop for new-index from new-start
                     below (+ new-start new-count)
                     for line = (aref new-lines new-index)
                     for rank = (gethash line new-ranks 0)
                     for positions = (gethash line old-occurrences)
                     do (setf (gethash line new-ranks) (1+ rank))
                        (when (and positions (< rank (length positions)))
                          (vector-push-extend
                           (cons (aref positions rank) new-index)
                           candidates)))
               (let* ((tails (make-array 0 :adjustable t :fill-pointer 0))
                      (predecessors
                       (make-array (length candidates) :initial-element nil)))
                 (loop for candidate across candidates
                       for candidate-index from 0
                       for old-index = (car candidate)
                       do (let ((low 0)
                                (high (length tails)))
                            (loop while (< low high)
                                  do (let ((middle (floor (+ low high) 2)))
                                       (if (< (car (aref candidates (aref tails middle)))
                                              old-index)
                                           (setf low (1+ middle))
                                           (setf high middle))))
                            (when (plusp low)
                              (setf (aref predecessors candidate-index)
                                    (aref tails (1- low))))
                            (if (= low (length tails))
                                (vector-push-extend candidate-index tails)
                                (setf (aref tails low) candidate-index))))
                 (when (plusp (length tails))
                   (loop with candidate-index = (aref tails (1- (length tails)))
                         while candidate-index
                         do (push (aref candidates candidate-index) matches)
                            (setf candidate-index
                                  (aref predecessors candidate-index)))))
               (loop with old-gap-start = old-start
                     with new-gap-start = new-start
                     for match in matches
                     for old-index = (car match)
                     for new-index = (cdr match)
                     do (copy-run old-gap-start
                                  new-gap-start
                                  (- old-index old-gap-start)
                                  (- new-index new-gap-start))
                        (when (and (< old-index (length newline-sequence))
                                   (< new-index (length newline-styles)))
                          (setf (aref newline-styles new-index)
                                (aref newline-sequence old-index)))
                        (setf old-gap-start (1+ old-index)
                              new-gap-start (1+ new-index))
                     finally
                       (copy-run old-gap-start
                                 new-gap-start
                                 (- (+ old-start old-count) old-gap-start)
                                 (- (+ new-start new-count) new-gap-start))))))
        (collect-lines original-text original-lines)
        (collect-lines text new-lines)
        (count-lines original-lines old-line-counts old-line-positions)
        (count-lines new-lines new-line-counts nil)
        (loop for line across new-lines
              for new-index from 0
              when (and (= (gethash line old-line-counts 0) 1)
                        (= (gethash line new-line-counts 0) 1))
                do (vector-push-extend
                    (cons (gethash line old-line-positions) new-index)
                    candidates))
        (let* ((tails (make-array 0 :adjustable t :fill-pointer 0))
               (predecessors
                (make-array (length candidates) :initial-element nil)))
          (loop for candidate across candidates
                for candidate-index from 0
                for old-index = (car candidate)
                do (let ((low 0)
                         (high (length tails)))
                     (loop while (< low high)
                           do (let ((middle (floor (+ low high) 2)))
                                (if (< (car (aref candidates (aref tails middle)))
                                       old-index)
                                    (setf low (1+ middle))
                                    (setf high middle))))
                     (when (plusp low)
                       (setf (aref predecessors candidate-index)
                             (aref tails (1- low))))
                     (if (= low (length tails))
                         (vector-push-extend candidate-index tails)
                         (setf (aref tails low) candidate-index))))
          (when (plusp (length tails))
            (loop with candidate-index = (aref tails (1- (length tails)))
                  while candidate-index
                  do (push (aref candidates candidate-index) matches)
                     (setf candidate-index
                           (aref predecessors candidate-index)))))
        (loop with old-start = 0
              with new-start = 0
              for match in matches
              for old-index = (car match)
              for new-index = (cdr match)
              do (map-run old-start
                           new-start
                           (- old-index old-start)
                           (- new-index new-start))
                 (when (and (< old-index (length newline-sequence))
                            (< new-index (length newline-styles)))
                   (setf (aref newline-styles new-index)
                         (aref newline-sequence old-index)))
                 (setf old-start (1+ old-index)
                       new-start (1+ new-index))
              finally
                (map-run old-start
                          new-start
                          (- (length original-lines) old-start)
                          (- (length new-lines) new-start)))
        (with-output-to-string (output)
          (loop with newline-index = 0
                for character across text
                do (if (char= character #\Linefeed)
                       (let ((newline-style (aref newline-styles newline-index)))
                         (when (eq newline-style :crlf)
                           (write-char #\Return output))
                         (write-char #\Linefeed output)
                         (incf newline-index))
                       (write-char character output)))))))
  (defun %append-utf-8-codepoint (octets code)
    (cond
      ((<= code #x7f) (vector-push-extend code octets))
      ((<= code #x7ff)
        (vector-push-extend (+ #xc0 (ash code -6)) octets)
        (vector-push-extend (+ #x80 (logand code #x3f)) octets))
      ((<= #xd800 code #xdfff)
       (error "Surrogate code point U+~X cannot be encoded as UTF-8" code))
      ((<= code #xffff)
        (vector-push-extend (+ #xe0 (ash code -12)) octets)
        (vector-push-extend (+ #x80 (logand (ash code -6) #x3f)) octets)
        (vector-push-extend (+ #x80 (logand code #x3f)) octets))
      ((<= code #x10ffff)
        (vector-push-extend (+ #xf0 (ash code -18)) octets)
        (vector-push-extend (+ #x80 (logand (ash code -12) #x3f)) octets)
        (vector-push-extend (+ #x80 (logand (ash code -6) #x3f)) octets)
        (vector-push-extend (+ #x80 (logand code #x3f)) octets))
      (t (error "Code point U+~X cannot be encoded as UTF-8" code))))
  (defun %encode-utf-8-string (text)
    (let ((octets
           (make-array 0
                       :element-type
                       '(unsigned-byte 8)
                       :adjustable
                       t
                       :fill-pointer
                       0)))
      (loop for character across text
            do (%append-utf-8-codepoint octets (char-code character)))
      octets))
  (defun %encode-latin-1-string (text)
    (let ((octets
           (make-array 0
                       :element-type
                       '(unsigned-byte 8)
                       :adjustable
                       t
                       :fill-pointer
                       0)))
      (loop for character across text
            for code = (char-code character)
            do (unless (<= code #xff)
                 (error "Character U+~X cannot be encoded as Latin-1" code)) (vector-push-extend
                                                                              code
                                                                              octets))
      octets))
  (defun %encode-file-text (text format)
    (let* ((physical-text
            (%expand-file-newlines text
                                   (%file-format-newline format)
                                   (%file-format-newline-sequence format)
                                   (%file-format-original-text format)))
           (body
            (ecase (%file-format-encoding format)
              (:utf-8 (%encode-utf-8-string physical-text))
              (:latin-1 (%encode-latin-1-string physical-text))))
           (bom-length (if (%file-format-bom-p format) 3 0))
           (octets
            (make-array (+ bom-length (length body))
                        :element-type (quote (unsigned-byte 8)))))
      (when (%file-format-bom-p format)
        (setf (aref octets 0) #xef
              (aref octets 1) #xbb
              (aref octets 2) #xbf))
      (replace octets body :start1 bom-length)
      octets)))
