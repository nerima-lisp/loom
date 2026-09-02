(in-package #:loom/test)

(describe
  "LSP domain values"
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

  (it-each
      ((1 "error") (2 "warning") (3 "info") (4 "hint") (nil "info")
       (99 "info"))
      "maps severity ~A to ~A"
      (severity expected)
    (expect (lsp-diagnostic-severity-name severity) :to-equal expected)))
