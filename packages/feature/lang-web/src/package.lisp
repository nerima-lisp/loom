(defpackage #:loom/feature/lang-web
  (:use #:cl))

(progn
  (defparameter loom/feature/lang-web::+typescript-keywords+
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
  (loom/feature/mode:register-major-mode
   :typescript
   :name "TypeScript"
   :aliases '("ts")
   :extensions '("ts" "mts" "cts")
   :comment-prefix "//" :comment-start "//" :comment-end nil
   :skip-closing-delimiter t
   :indentation-width 2 :tab-width 8
   :truncate-lines t :language-id "typescript"
   :keywords loom/feature/lang-web::+typescript-keywords+)
  (loom/feature/mode:register-major-mode
   :typescript-react
   :name "TypeScript React"
   :aliases '("tsx")
   :extensions '("tsx")
   :comment-prefix "//" :comment-start "//" :comment-end nil
   :skip-closing-delimiter t
   :indentation-width 2 :tab-width 8
   :truncate-lines t :language-id "typescriptreact"
   :keywords loom/feature/lang-web::+typescript-keywords+)
  (loom/feature/mode:register-major-mode
   :json
   :name "JSON"
   :extensions '("json")
   :comment-prefix nil :comment-start nil :comment-end nil
   :skip-closing-delimiter t
   :indentation-width 2 :tab-width 8
   :truncate-lines t :language-id "json"
   :keywords nil)
  (loom/feature/mode:register-major-mode
   :javascript
   :name "JavaScript"
   :aliases '("js" "javascript")
   :extensions '("js" "mjs" "cjs")
   :language-id "javascript"
   :keywords '("as" "async" "await" "break" "case" "catch" "class" "const"
               "continue" "debugger" "default" "delete" "do" "else" "export"
               "extends" "false" "finally" "for" "from" "function" "get" "if"
               "import" "in" "instanceof" "let" "new" "null" "of" "return"
               "set" "static" "super" "switch" "this" "throw" "true" "try"
               "typeof" "var" "void" "while" "with" "yield"))
  (loom/feature/mode:register-major-mode
   :javascript-react
   :name "JavaScript React"
   :aliases '("jsx")
   :extensions '("jsx")
   :language-id "javascriptreact"
   :keywords '("as" "async" "await" "break" "case" "catch" "class" "const"
               "continue" "debugger" "default" "delete" "do" "else" "export"
               "extends" "false" "finally" "for" "from" "function" "get" "if"
               "import" "in" "instanceof" "let" "new" "null" "of" "return"
               "set" "static" "super" "switch" "this" "throw" "true" "try"
               "typeof" "var" "void" "while" "with" "yield"))
  (loom/feature/mode:register-major-mode
   :html
   :name "HTML"
   :extensions '("html" "htm")
   :language-id "html"
   :keywords '("article" "body" "button" "div" "doctype" "footer" "form"
               "head" "header" "html" "img" "input" "li" "link" "main" "meta"
               "nav" "ol" "p" "script" "section" "span" "style" "table" "td"
               "th" "title" "tr" "ul"))
  (loom/feature/mode:register-major-mode
   :css
   :name "CSS"
   :extensions '("css")
   :language-id "css"
   :keywords '("absolute" "auto" "block" "currentColor" "flex" "fixed" "grid"
               "inherit" "initial" "inline" "important" "none" "relative"
               "revert" "static" "sticky" "transparent" "unset" "var"))
  (loom/feature/mode:register-major-mode
   :yaml
   :name "YAML"
   :extensions '("yaml" "yml")
   :language-id "yaml"
   :keywords '("false" "no" "null" "off" "on" "true" "yes")))
