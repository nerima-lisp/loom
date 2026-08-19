;;;; t/unit/major-mode-syntax-highlighting-test.lisp
;;;;
;;;; Mode-aware syntax highlighting behavior for generic and Lisp tokenizers.
(in-package #:loom/test)

(describe
  "syntax-highlight-line-for-mode"
  (it
    "uses mode metadata to classify non-Lisp source"
    (let ((line "def answer(): # note"))
      (expect (%mode-token-kinds line :python)
              :to-equal
              '(:keyword :whitespace :plain :delimiter :delimiter :delimiter
                :whitespace :comment))
      (expect (%mode-token-texts line :python)
              :to-equal
              '("def" " " "answer" "(" ")" ":" " " "# note"))
      (expect (apply #'concatenate 'string (%mode-token-texts line :python))
              :to-equal line)))

  (it
    "classifies generic numbers, keywords, and strings"
    (let ((line ":value 42 \"text\""))
      (expect (%mode-token-kinds line :python)
              :to-equal
              '(:delimiter :plain :whitespace :number :whitespace :string))
      (expect (apply #'concatenate 'string (%mode-token-texts line :python))
              :to-equal line)))

  (it-each
      ((:rust "fn main() { // note"
        (:keyword :whitespace :plain :delimiter :delimiter :whitespace
         :delimiter :whitespace :comment)
        ("fn" " " "main" "(" ")" " " "{" " " "// note"))
       (:unknown "42 \"text\""
        (:number :whitespace :string)
        ("42" " " "\"text\"")))
      "uses ~A's generic syntax rules"
      (mode line expected-kinds expected-texts)
    (expect (%mode-token-kinds line mode) :to-equal expected-kinds)
    (expect (%mode-token-texts line mode) :to-equal expected-texts)
    (expect (apply #'concatenate 'string (%mode-token-texts line mode))
            :to-equal line))

  (it
    "keeps Common Lisp on its reader-aware tokenizer"
    (expect (%mode-token-kinds "(defun run ()) ; note" :common-lisp)
            :to-contain :keyword)
    (expect (%mode-token-kinds "(defun run ()) ; note" "lisp")
            :to-contain :comment)))
