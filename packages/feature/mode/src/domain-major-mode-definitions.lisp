;;;; packages/feature/mode/src/domain-major-mode-definitions.lisp
;;;;
;;;; Built-in major-mode metadata.  Lookup APIs live in
;;;; domain-major-mode.lisp; registry state and mutation support live in
;;;; domain-major-mode-registry-support.lisp and
;;;; domain-major-mode-registry.lisp.
(in-package #:loom/feature/mode)

;; TypeScript and TypeScript React share one vocabulary; the two modes differ
;; only in :language-id, which LSP servers use to select the JSX dialect.
(defparameter +typescript-keywords+
  '("abstract" "any" "as" "asserts" "async" "await" "bigint" "boolean"
    "break" "case" "catch" "class" "const" "constructor" "continue"
    "declare" "default" "delete" "do" "else" "enum" "export" "extends"
    "false" "finally" "for" "from" "function" "get" "if" "implements"
    "import" "in" "infer" "instanceof" "interface" "is" "keyof" "let"
    "namespace" "never" "new" "null" "number" "of" "private" "protected"
    "public" "readonly" "return" "satisfies" "set" "static" "string"
    "super" "switch" "symbol" "this" "throw" "true" "try" "type" "typeof"
    "undefined" "unknown" "var" "void" "while" "yield")
  "Keyword vocabulary shared by the TypeScript and TypeScript React modes.")

(defparameter +major-mode-definitions+
  `((:fundamental
     :name "Fundamental"
     :comment-prefix nil
     :indentation-width 2
     :truncate-lines t
     :language-id "plaintext"
     :keywords ())
    (:common-lisp
     :name "Common Lisp"
     :comment-prefix ";"
     :aliases ("lisp" "cl" "common lisp")
     :indentation-width 2
     :truncate-lines t
     :language-id "commonlisp"
     :keywords ("and" "block" "case" "catch" "defclass" "defconstant"
                 "defgeneric" "defmacro" "defmethod" "defpackage"
                 "defparameter" "defstruct" "deftype" "defun" "defvar"
                 "do" "do*" "dolist" "dotimes" "ecase" "else" "eval-when"
                 "flet" "function" "go" "if" "in-package" "labels" "let"
                 "let*" "loop" "macrolet" "multiple-value-bind"
                 "multiple-value-call" "multiple-value-prog1"
                 "multiple-value-setq" "nil" "or" "otherwise" "prog" "prog1"
                 "progn" "progv" "quote" "return" "return-from" "setf"
                 "tagbody" "the" "throw" "typecase" "unless" "unwind-protect"
                 "when" "with-open-file" "with-output-to-string" "with-slots"
                 "with-standard-io-syntax" "write" "t"))
    (:python
     :name "Python"
     :comment-prefix "#"
     :indentation-width 4
     :truncate-lines t
     :language-id "python"
     :keywords ("and" "as" "assert" "async" "await" "break" "case"
                 "class" "continue" "def" "del" "elif" "else" "except"
                 "False" "finally" "for" "from" "global" "if" "import"
                 "in" "is" "lambda" "match" "None" "nonlocal" "not" "or"
                 "pass" "raise" "return" "True" "try" "while" "with" "yield"))
    (:rust
     :name "Rust"
     :comment-prefix "//"
     :indentation-width 4
     :truncate-lines t
     :language-id "rust"
     :keywords ("as" "async" "await" "break" "const" "continue" "crate"
                 "dyn" "else" "enum" "extern" "fn" "for" "if" "impl"
                 "in" "let" "loop" "match" "mod" "move" "mut" "pub"
                 "ref" "return" "self" "Self" "static" "struct" "super"
                 "trait" "type" "unsafe" "use" "where" "while"))
    (:shell
     :name "Shell"
     :comment-prefix "#"
     :aliases ("sh" "bash" "zsh")
     :indentation-width 2
     :truncate-lines t
     :language-id "shellscript"
     :keywords ("case" "do" "done" "elif" "else" "esac" "fi" "for"
                 "function" "if" "in" "select" "then" "until" "while"))
    (:emacs-lisp
     :name "Emacs Lisp"
     :comment-prefix ";"
     :aliases ("el" "elisp")
     :indentation-width 2
     :truncate-lines t
     :language-id "emacs-lisp"
     :keywords ("and" "catch" "cl-defmacro" "cl-defun" "cond"
                 "condition-case" "defcustom" "defface" "defgroup"
                 "defmacro" "defsubst" "defun" "defvar" "defvar-local"
                 "dolist" "dotimes" "if" "ignore-errors" "interactive"
                 "lambda" "let" "let*" "nil" "or" "pcase" "prog1" "progn"
                 "provide" "require" "save-excursion" "save-restriction"
                 "setq" "setq-default" "t" "throw" "unless"
                 "unwind-protect" "when" "while" "with-current-buffer"
                 "with-temp-buffer"))
    (:nix
     :name "Nix"
     :comment-prefix "#"
     :indentation-width 2
     :truncate-lines t
     :language-id "nix"
     :keywords ("abort" "assert" "baseNameOf" "builtins" "derivation"
                 "dirOf" "else" "false" "fetchTarball" "fetchurl" "if"
                 "import" "in" "inherit" "isNull" "let" "map" "null" "or"
                 "rec" "removeAttrs" "then" "throw" "toString" "true"
                 "with"))
    (:typescript
     :name "TypeScript"
     :comment-prefix "//"
     :aliases ("ts")
     :indentation-width 2
     :truncate-lines t
     :language-id "typescript"
     :keywords ,+typescript-keywords+)
    (:typescript-react
     :name "TypeScript React"
     :comment-prefix "//"
     :aliases ("tsx")
     :indentation-width 2
     :truncate-lines t
     :language-id "typescriptreact"
     :keywords ,+typescript-keywords+)
    (:markdown
     :name "Markdown"
     :comment-prefix "#"
     :indentation-width 2
     :truncate-lines nil
     :language-id "markdown"
     :keywords ())
    (:org
     :name "Org"
     :comment-prefix "#"
     :indentation-width 2
     :truncate-lines nil
     :language-id "org"
     :keywords ("CANCELLED" "CLOSED" "DEADLINE" "DONE" "NEXT"
                 "SCHEDULED" "TODO" "WAITING"))
    (:json
     :name "JSON"
     :comment-prefix nil
     :indentation-width 2
     :truncate-lines t
     :language-id "json"
     :keywords ())
    (:text
     :name "Text"
     :comment-prefix nil
     :aliases ("plain text")
     :indentation-width 2
     :truncate-lines nil
     :language-id "plaintext"
     :keywords ()))
  "The built-in major modes and the metadata consumed by editor features.")
