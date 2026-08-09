;;;; t/unit/syntax-highlighting-test.lisp
;;;;
;;;; Domain-layer tests for line-local Common Lisp token classification.
(in-package #:loom/test)

(defun %syntax-token-kinds (line)
  (mapcar #'syntax-token-kind (syntax-highlight-line line)))

(defun %syntax-token-texts (line)
  (mapcar #'syntax-token-text (syntax-highlight-line line)))

(describe
  "syntax-highlight-line"
  (it
    "preserves source text while classifying common Lisp forms"
    (let ((line "(defun greet (name) \"Hi\" 42) ; note"))
      (expect (%syntax-token-kinds line)
              :to-equal
              '(:delimiter :keyword :whitespace :plain :whitespace
                :delimiter :plain :delimiter :whitespace :string :whitespace
                :number :delimiter :whitespace :comment))
      (expect (%syntax-token-texts line)
              :to-equal
              '("(" "defun" " " "greet" " " "(" "name" ")" " "
                "\"Hi\"" " " "42" ")" " " "; note"))
      (expect (apply #'concatenate 'string (%syntax-token-texts line))
              :to-equal line)))

  (it
    "recognizes reader prefixes, keywords, characters, and numbers"
    (let ((line ":answer #\\Space 3.14 -7 t"))
      (expect (%syntax-token-kinds line)
              :to-equal
              '(:keyword :whitespace :character :whitespace :number
                :whitespace :number :whitespace :keyword))
      (expect (%syntax-token-texts line)
              :to-equal
              '(":answer" " " "#\\Space" " " "3.14" " " "-7" " " "t"))))

  (it
    "keeps same-line block comments and unterminated strings local to the line"
    (let ((line "#| hidden |# (quote \"unfinished"))
      (expect (%syntax-token-kinds line)
              :to-equal
              '(:comment :whitespace :delimiter :keyword :whitespace :string))
      (expect (%syntax-token-texts line)
              :to-equal
              '("#| hidden |#" " " "(" "quote" " " "\"unfinished"))))

  (it
    "returns no tokens for an empty line"
    (expect (syntax-highlight-line "") :to-be nil)))
