(in-package #:loom/feature/mode)

(defparameter +major-mode-definitions+
  `((:fundamental :name "Fundamental"
     :comment-prefix nil
     :comment-start nil
     :comment-end nil
     :skip-closing-delimiter nil
     :indentation-width 2
     :truncate-lines t
     :language-id "plaintext"
     :keywords () :tab-width 8)
    (:python :name "Python"
     :comment-prefix "#"
     :comment-start "#"
     :comment-end nil
     :skip-closing-delimiter t
     :indentation-width 4
     :truncate-lines t
     :language-id "python"
     :keywords ("and" "as" "assert" "async" "await" "break" "case"
                "class" "continue" "def" "del" "elif" "else" "except"
                "False" "finally" "for" "from" "global" "if" "import"
                "in" "is" "lambda" "match" "None" "nonlocal" "not" "or"
                "pass" "raise" "return" "True" "try" "while" "with" "yield") :tab-width 8)
    (:rust :name "Rust"
     :comment-prefix "//"
     :comment-start "//"
     :comment-end nil
     :skip-closing-delimiter t
     :indentation-width 4
     :truncate-lines t
     :language-id "rust"
     :keywords ("as" "async" "await" "break" "const" "continue" "crate"
                "dyn" "else" "enum" "extern" "fn" "for" "if" "impl"
                "in" "let" "loop" "match" "mod" "move" "mut" "pub"
                "ref" "return" "self" "Self" "static" "struct" "super"
                "trait" "type" "unsafe" "use" "where" "while") :tab-width 8)
    (:shell :name "Shell"
     :comment-prefix "#"
     :comment-start "#"
     :comment-end nil
     :skip-closing-delimiter t
     :aliases ("sh" "bash" "zsh")
     :indentation-width 2
     :truncate-lines t
     :language-id "shellscript"
     :keywords ("case" "do" "done" "elif" "else" "esac" "fi" "for"
                "function" "if" "in" "select" "then" "until" "while") :tab-width 8)
    (:text :name "Text"
     :comment-prefix nil
     :comment-start nil
     :comment-end nil
     :skip-closing-delimiter nil
     :aliases ("plain text")
     :indentation-width 2
     :truncate-lines nil
     :language-id "plaintext"
     :keywords () :tab-width 8))
  "The built-in major modes and the metadata consumed by editor features.")
