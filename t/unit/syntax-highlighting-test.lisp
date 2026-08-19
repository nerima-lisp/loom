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
    "keeps escaped strings and delimiter character literals intact"
    (let ((line "\"a\\\"b\" #\\; #\\("))
      (expect (%syntax-token-kinds line)
              :to-equal
              '(:string :whitespace :character :whitespace :character))
      (expect (%syntax-token-texts line)
              :to-equal
              '("\"a\\\"b\"" " " "#\\;" " " "#\\("))
      (expect (apply #'concatenate 'string (%syntax-token-texts line))
              :to-equal
              line)))

  (it
    "keeps an unterminated block comment local to the line"
    (let ((line "#| unfinished")
          (tokens (syntax-highlight-line "#| unfinished")))
      (expect (mapcar #'syntax-token-kind tokens)
              :to-equal
              '(:comment))
      (expect (mapcar #'syntax-token-text tokens)
              :to-equal
              (list line))))

  (it
    "returns no tokens for an empty line"
    (expect (syntax-highlight-line "") :to-be nil)))

(describe
  "syntax-highlight-line-for-mode"
  (it
    "uses major-mode metadata for non-Common Lisp tokenization"
    (let ((line "fn main() { 42 } // note"))
      (expect (mapcar #'syntax-token-kind
                      (syntax-highlight-line-for-mode line :rust))
              :to-equal
              '(:keyword :whitespace :plain :delimiter :delimiter
                :whitespace :delimiter :whitespace :number :whitespace
                :delimiter :whitespace :comment))
      (expect (mapcar #'syntax-token-text
                      (syntax-highlight-line-for-mode line :rust))
              :to-equal
              '("fn" " " "main" "(" ")" " " "{" " " "42" " " "}" " "
                "// note")))))
