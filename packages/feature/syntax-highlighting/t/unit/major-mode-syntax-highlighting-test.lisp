(in-package #:loom/test)

(describe
  "syntax-highlight-line-for-mode"
  (it
    "uses mode metadata to classify non-Lisp source"
    (let ((line "def answer(): # note"))
      (expect (mapcar #'syntax-token-kind (syntax-highlight-line-for-mode line :python))
              :to-equal
              '(:keyword :whitespace :plain :delimiter :delimiter :delimiter
                :whitespace :comment))
      (expect (mapcar #'syntax-token-text (syntax-highlight-line-for-mode line :python))
              :to-equal
              '("def" " " "answer" "(" ")" ":" " " "# note"))
      (expect (apply #'concatenate 'string (mapcar #'syntax-token-text (syntax-highlight-line-for-mode line :python)))
              :to-equal line)))

  (it
    "classifies generic numbers, keywords, and strings"
    (let ((line ":value 42 \"text\""))
      (expect (mapcar #'syntax-token-kind (syntax-highlight-line-for-mode line :python))
              :to-equal
              '(:delimiter :plain :whitespace :number :whitespace :string))
      (expect (apply #'concatenate 'string (mapcar #'syntax-token-text (syntax-highlight-line-for-mode line :python)))
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
    (expect (mapcar #'syntax-token-kind (syntax-highlight-line-for-mode line mode)) :to-equal expected-kinds)
    (expect (mapcar #'syntax-token-text (syntax-highlight-line-for-mode line mode)) :to-equal expected-texts)
    (expect (apply #'concatenate 'string (mapcar #'syntax-token-text (syntax-highlight-line-for-mode line mode)))
            :to-equal line))

  (it-each
      ((:nix "let x = 1; # note"
        (:keyword :whitespace :plain :whitespace :plain :whitespace
         :number :delimiter :whitespace :comment)
        ("let" " " "x" " " "=" " " "1" ";" " " "# note"))
       (:typescript "const x = 1; // note"
        (:keyword :whitespace :plain :whitespace :plain :whitespace
         :number :delimiter :whitespace :comment)
        ("const" " " "x" " " "=" " " "1" ";" " " "// note"))
       (:typescript-react "const x = 1; // note"
        (:keyword :whitespace :plain :whitespace :plain :whitespace
         :number :delimiter :whitespace :comment)
        ("const" " " "x" " " "=" " " "1" ";" " " "// note"))
       (:emacs-lisp "(defun run () ; note"
        (:delimiter :keyword :whitespace :plain :whitespace :delimiter
         :delimiter :whitespace :comment)
        ("(" "defun" " " "run" " " "(" ")" " " "; note"))
       (:org "* TODO task # note"
        (:plain :whitespace :keyword :whitespace :plain :whitespace
         :comment)
        ("*" " " "TODO" " " "task" " " "# note")))
      "colors ~A keywords and comments from mode metadata"
      (mode line expected-kinds expected-texts)
    (expect (mapcar #'syntax-token-kind (syntax-highlight-line-for-mode line mode)) :to-equal expected-kinds)
    (expect (mapcar #'syntax-token-text (syntax-highlight-line-for-mode line mode)) :to-equal expected-texts)
    (expect (apply #'concatenate 'string (mapcar #'syntax-token-text (syntax-highlight-line-for-mode line mode)))
            :to-equal line))

  (it
    "keeps Emacs Lisp on its own vocabulary rather than Common Lisp's"
    (let ((line "(defcustom loom-x 1)"))
      (expect (mapcar #'syntax-token-kind (syntax-highlight-line-for-mode line :emacs-lisp))
              :to-equal
              '(:delimiter :keyword :whitespace :plain :whitespace :number
                :delimiter))
      (expect (mapcar #'syntax-token-kind (syntax-highlight-line-for-mode line :common-lisp))
              :to-equal
              '(:delimiter :plain :whitespace :plain :whitespace :number
                :delimiter))))

  (it
    "keeps Common Lisp on its reader-aware tokenizer"
    (expect (mapcar #'syntax-token-kind (syntax-highlight-line-for-mode "(defun run ()) ; note" :common-lisp))
            :to-contain :keyword)
    (expect (mapcar #'syntax-token-kind (syntax-highlight-line-for-mode "(defun run ()) ; note" "lisp"))
            :to-contain :comment)))
