;;;; packages/feature/mode/src/domain-major-mode-keywords.lisp
;;;;
;;;; Static language vocabularies used by built-in major-mode metadata.
(in-package #:loom/feature/mode)

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
