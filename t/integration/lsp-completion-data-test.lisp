;;;; t/integration/lsp-completion-data-test.lisp
;;;;
;;;; Pure completion-prefix and popup-item transformations.
(in-package #:loom/test)

(describe
  "LSP completion data transformations"
  (it-each
      (("foo" 3 0)
       ("foo-bar" 7 0)
       ("foo +" 5 4)
       ("" 0 0))
      "finds the symbol prefix boundary in ~S at column ~A"
      (content column expected)
    (let ((buffer (make-buffer :initial-content content)))
      (expect (loom/feature/lsp::%lsp-completion-prefix-column
               buffer 0 column)
              :to-equal expected)))

  (it
    "renders completion details without changing insertion text"
    (let ((item (make-lsp-completion-item
                 "map"
                 :insert-text "mapcar"
                 :detail "function")))
      (expect (loom/feature/lsp::%lsp-completion-popup-items (list item))
              :to-equal '(("map  function" . "mapcar")))))

  (it
    "uses the label when completion detail is absent"
    (let ((item (make-lsp-completion-item
                 "lambda"
                 :insert-text nil
                 :detail nil)))
      (expect (loom/feature/lsp::%lsp-completion-popup-items (list item))
              :to-equal '(("lambda" . "lambda")))))
  )
