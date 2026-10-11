(in-package #:loom/test)

(describe
  "LSP domain values"
  (it
    "round trips UTF-16 positions at every character boundary"
    (dolist (text (list "" "abc" "日本語"
                       (format nil "a~Cb~Cc" (code-char #x1f600)
                               (code-char #x1f642))))
      (loop for column from 0 to (length text)
            do (expect
                (loom/feature/lsp:lsp-character-to-column
                 text (loom/feature/lsp:lsp-column-to-character text column))
                :to-equal column))))

  (it
    "counts supplementary characters as two UTF-16 units"
    (let ((text (format nil "a~Cb~C" (code-char #x1f600) (code-char #x1f642))))
      (expect (loop for column from 0 to 4
                    collect (loom/feature/lsp:lsp-column-to-character text column))
              :to-equal '(0 1 3 4 6))
      (expect (loop for character from 0 to 6
                    collect (loom/feature/lsp:lsp-character-to-column text character))
              :to-equal '(0 1 1 2 3 3 4))))

  (it
    "clamps UTF-16 offsets beyond the end of a line"
    (expect (loom/feature/lsp:lsp-character-to-column "" 10) :to-equal 0)
    (expect (loom/feature/lsp:lsp-character-to-column "日本語" 10) :to-equal 3)
    (expect (loom/feature/lsp:lsp-character-to-column
             (string (code-char #x1f600)) 10)
            :to-equal 1))

  (it
    "defaults an omitted position to the document origin"
    (let ((position (make-lsp-position)))
      (expect (list (lsp-position-line position)
                    (lsp-position-character position))
              :to-equal
              '(0 0))))

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

  (it
    "preserves document metadata and uses completion label fallback"
    (let* ((document (make-lsp-document "file:///main.lisp" "commonlisp"
                                        1 ""))
           (item (make-lsp-completion-item "format"
                                           :detail "function"
                                           :kind 3)))
      (expect (lsp-document-version document) :to-equal 1)
      (expect (lsp-completion-item-text item) :to-equal "format")))

  (it
    "prefers completion insert text when supplied"
    (let ((item (make-lsp-completion-item "format(...)"
                                          :insert-text "format")))
      (expect (lsp-completion-item-text item) :to-equal "format")))

  (it
    "preserves a definition location as a domain value"
    (let* ((range (make-lsp-range (make-lsp-position 4 2)
                                  (make-lsp-position 4 8)))
           (location (make-lsp-location "file:///lib.lisp" range)))
      (expect (lsp-location-uri location) :to-equal "file:///lib.lisp")
      (expect (list (lsp-position-line
                     (lsp-range-start (lsp-location-range location)))
                    (lsp-position-character
                     (lsp-range-start (lsp-location-range location)))
                    (lsp-position-line
                     (lsp-range-end (lsp-location-range location)))
                    (lsp-position-character
                     (lsp-range-end (lsp-location-range location))))
              :to-equal '(4 2 4 8))))

  (it-each
      ((1 "error") (2 "warning") (3 "info") (4 "hint") (nil "info")
       (99 "info"))
      "maps severity ~A to ~A"
      (severity expected)
    (expect (lsp-diagnostic-severity-name severity) :to-equal expected)))
