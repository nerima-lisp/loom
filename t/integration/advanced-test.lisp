;;;; t/integration/advanced-test.lisp
;;;;
;;;; High-level cl-weave registrations over the real Loom buffer protocol.
(in-package #:loom/test)

(describe
  "cl-weave advanced registrations"
  (cl-weave:it-each
      ((0 "x" "xabc")
       (1 "x" "axbc")
       (3 "x" "abcx"))
      "inserts ~A at zero-based column ~D"
      (column inserted expected)
    (let ((buffer (make-buffer :initial-content "abc")))
      (buffer-set-point buffer 0 column)
      (buffer-insert-string buffer inserted)
      (expect (buffer-text buffer) :to-equal expected)
      (expect (buffer-point-column buffer)
              :to-equal (+ column (length inserted)))))

  (cl-weave:it-property
      "keeps generated insertion points and text consistent"
      ((column (cl-weave:gen-integer :min 0 :max 6))
       (character (cl-weave:gen-character :alphabet "abc")))
    (%with-buffer-at (buffer "abcdef" 0 column)
      (let ((inserted (string character)))
        (buffer-insert-string buffer inserted)
        (expect (buffer-point-column buffer)
                :to-equal (1+ column))
        (expect (buffer-text buffer)
                :to-equal
                (concatenate 'string
                             (subseq "abcdef" 0 column)
                             inserted
                             (subseq "abcdef" column))))))

  (cl-weave:it-property
      "round-trips generated UTF-8 frame payloads"
      ((character (cl-weave:gen-character :alphabet "abc日本語")))
    (let ((json (format nil "{\"text\":\"~A\"}" character)))
      (multiple-value-bind (decoded used status)
          (loom/feature/lsp::loom-lsp-frame-decode
           (loom/feature/lsp::loom-lsp-frame-encode json))
        (expect decoded :to-equal json)
        (expect used :to-be-greater-than (length json))
        (expect status :to-be :complete))))

  (cl-weave:it-property
      "normalizes generated command prefixes"
      ((length (cl-weave:gen-integer :min 0 :max 12)))
    (let* ((command "forward-char")
           (prefix (subseq command 0 length))
           (input (format nil "  ~A  " (string-upcase prefix))))
      (expect (member command
                      (loom/application:command-completion-candidates input)
                      :test #'string=)
              :to-be-truthy)))

  (cl-weave:it-fuzz
      "accepts generated insertion positions"
      ((column (cl-weave:gen-integer :min 0 :max 6)))
      (:trials 16 :timeout-per-trial 1)
    (%with-buffer-at (buffer "abcdef" 0 column)
      (buffer-insert-string buffer "!")
      (expect (buffer-point-column buffer) :to-equal (1+ column))
      (expect (length (buffer-text buffer)) :to-equal 7))))


(describe
  "continuation observations"
  (cl-weave:it
    "captures multiple buffer observations through a continuation"
    (let ((buffer (make-buffer :initial-content "alpha")))
      (cl-weave:with-continuation-values (observations next calledp)
          (funcall (lambda (continuation)
                     (funcall continuation
                              (buffer-text buffer)
                              (buffer-line-count buffer)))
                   #'next)
        (expect calledp :to-be-truthy)
        (expect observations :to-equal (list "alpha" 1))))))
